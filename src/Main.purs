module WAGSI.Main where

import Prelude

import Control.Alt ((<|>))
import Control.Comonad.Cofree (Cofree, (:<))
import Control.Promise (toAffE)
import Data.Array ((..))
import Data.Compactable (compact)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.FunctorWithIndex (mapWithIndex)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Newtype (unwrap)
import Data.Nullable (toNullable)
import Data.Traversable (sequence)
import Data.Tuple (fst, snd)
import Data.Tuple.Nested ((/\), type (/\))
import Data.Typelevel.Num (class Nat, class Pos, toInt')
import Data.Typelevel.Undefined (undefined)
import Data.Vec as V
import Effect (Effect)
import Effect.Aff (Aff, error, forkAff, joinFiber, launchAff_, parallel, sequential, throwError, try)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import Effect.Class.Console as Log
import Effect.Ref as Ref
import FRP.Behavior (Behavior, behavior)
import FRP.Behavior.Mouse (position)
import FRP.Event (Event, makeEvent, subscribe)
import FRP.Event.Keyboard as Keyboard
import FRP.Event.Mouse (getMouse)
import FRP.Event.Mouse as Mouse
import Foreign (Foreign)
import Foreign.Object (Object)
import Foreign.Object as O
import Halogen as H
import Halogen.Aff (awaitBody, runHalogenAff)
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)
import Record as R
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)
import WAGS.Interpret (close, context, decodeAudioDataFromUri, defaultFFIAudio, getMicrophoneAndCamera, makeFloatArray, makePeriodicWave, makeUnitCache)
import WAGS.Run (Run, run)
import WAGS.WebAPI (AudioContext, BrowserAudioBuffer, BrowserFloatArray, BrowserPeriodicWave)
import WAGSI.Plumbing.Audio (piece)
import WAGSI.Plumbing.Hack (stash, wag)
import WAGSI.Plumbing.StashStuff (CacheStash, StashedSig)
import WAGSI.Plumbing.Types (NKeys, NKnobs, NSliders, NSwitches, Stash(..))
import WAGSI.Plumbing.Types (Stash)
import WAGSI.Plumbing.Types as Types
import Wagsi.Behavior (ref2Behavior)
import Wagsi.Vec (mapWithTypedIndex)

main :: Effect Unit
main =
  runHalogenAff do
    body <- awaitBody
    runUI component unit body

type StashInfo
  = { buffers :: Array String, periodicWaves :: Array String, floatArrays :: Array String }

type State
  =
  { unsubscribe :: Effect Unit
  , audioCtx :: Maybe AudioContext
  , audioStarted :: Boolean
  , canStopAudio :: Boolean
  , unsubscribeFromHalogen :: Maybe H.SubscriptionId
  , stashInfo :: StashInfo
  , musicRef :: Maybe (Ref.Ref { | Types.Music })
  }

data Action
  = Initialize
  | UpdateStashInfo StashInfo
  | StartAudio
  | StopAudio

component :: forall query input output m. MonadEffect m => MonadAff m => H.Component query input output m
component =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval { initialize = Just Initialize, handleAction = handleAction }
    }

cs :: forall buffers floatArrays periodicWaves. Event (StashedSig buffers floatArrays periodicWaves)
cs =
  compact
    ( makeEvent \k -> do
        cachedStash Nothing Just >>= k
        pure (pure unit)
    )

vRange :: forall n. Nat n => V.Vec n Int
vRange = V.fill identity

-- todo: avoid code dup in lens decl?
lenses
  :: Ref.Ref { | Types.Music }
  -> { | Types.Music' (Number -> Effect Unit) (Number -> Effect Unit) (Boolean -> Effect Unit) (Boolean -> Effect Unit) }
lenses rf =
  { knobs: mapWithTypedIndex (\p2n _ v -> void $ Ref.modify (\r -> r { knobs = V.updateAt p2n v r.knobs }) rf) vRange
  , sliders: mapWithTypedIndex (\p2n _ v -> void $ Ref.modify (\r -> r { sliders = V.updateAt p2n v r.sliders }) rf) vRange
  , switches: mapWithTypedIndex (\p2n _ v -> void $ Ref.modify (\r -> r { switches = V.updateAt p2n v r.switches }) rf) vRange
  , keyboard: mapWithTypedIndex (\p2n _ v -> void $ Ref.modify (\r -> r { keyboard = V.updateAt p2n v r.keyboard }) rf) vRange
  }

foreign import knobCb :: String -> (Number -> Effect Unit) -> Effect Unit

foreign import sliderCb :: String -> (Number -> Effect Unit) -> Effect Unit

foreign import switchCb :: String -> (Boolean -> Effect Unit) -> Effect Unit

foreign import keyboardCb :: String -> Array (Boolean -> Effect Unit) -> Effect Unit

initialMusic :: { | Types.Music }
initialMusic =
  { keyboard: V.fill (const false) :: V.Vec NKeys Boolean
  , knobs: V.fill (const 0.0) :: V.Vec NKnobs Number
  , sliders: V.fill (const 0.0) :: V.Vec NSliders Number
  , switches: V.fill (const false) :: V.Vec NSwitches Boolean
  }

initialState :: forall input. input -> State
initialState _ =
  { unsubscribe: pure unit
  , audioCtx: Nothing
  , audioStarted: false
  , canStopAudio: false
  , unsubscribeFromHalogen: Nothing
  , stashInfo: mempty
  , musicRef: Nothing
  }

classes :: forall r p. Array String -> HP.IProp (class :: String | r) p
classes = HP.classes <<< map H.ClassName

knob :: forall w i. String -> HH.HTML w i
knob id =
  HH.div [ classes [ "flex", "flex-col", "p-2" ] ]
    [ HH.p [ classes [ "text-center" ] ] [ HH.text id ]
    , HH.element (HH.ElemName "webaudio-knob") [ HP.id id ] []
    ]

switch :: forall w i. String -> HH.HTML w i
switch id =
  HH.div [ classes [ "flex", "flex-col", "p-2" ] ]
    [ HH.p [ classes [ "text-center" ] ] [ HH.text id ]
    , HH.element (HH.ElemName "webaudio-switch") [ HP.id id ] []
    ]

slider :: forall w i. String -> HH.HTML w i
slider id =
  HH.div [ classes [ "flex", "flex-col", "p-2" ] ]
    [ HH.p [ classes [ "text-center" ] ] [ HH.text id ]
    , HH.element (HH.ElemName "webaudio-slider")
        [ HP.attr (H.AttrName "direction") "vert", HP.id id ]
        []
    ]

render :: forall m. State -> H.ComponentHTML Action () m
render { audioStarted, canStopAudio, stashInfo } =
  HH.div [ classes [ "w-screen", "h-screen" ] ]
    [ HH.div [ classes [ "flex", "flex-col", "w-full", "h-full" ] ]
        [ HH.div [ classes [ "flex-grow" ] ] [ HH.div_ [ HH.p_ [ HH.text ("Stash info: " <> show stashInfo) ] ] ]
        , HH.div [ classes [ "flex-grow-0", "flex", "flex-row" ] ]
            [ HH.div [ classes [ "flex-grow" ] ]
                []
            , HH.div [ classes [ "flex", "flex-col" ] ]
                [ HH.h1 [ classes [ "text-center", "text-3xl", "font-bold" ] ]
                    [ HH.text "wagsi" ]
                , HH.div [ classes [ "flex", "flex-row" ] ]
                    (map (knob <<< append "knob" <<< show <<< add 1) (0 .. 9))
                , HH.div [ classes [ "flex", "flex-row" ] ]
                    ([ HH.div [ classes [ "flex-grow" ] ] [] ] <> (map (slider <<< append "slider" <<< show <<< add 1) (0 .. 9)) <> [ HH.div [ classes [ "flex-grow" ] ] [] ])
                , HH.div [ classes [ "flex", "flex-row" ] ]
                    ([ HH.div [ classes [ "flex-grow" ] ] [] ] <> (map (switch <<< append "switch" <<< show <<< add 1) (0 .. 9)) <> [ HH.div [ classes [ "flex-grow" ] ] [] ])
                , HH.div [ classes [ "flex", "flex-col" ], classes [ "p-2" ] ]
                    [ HH.p [ classes [ "text-center" ] ] [ HH.text "keyboard" ]
                    , HH.element (HH.ElemName "webaudio-keyboard")
                        [ HP.attr (H.AttrName "keys") (show $ toInt' (Proxy :: _ Types.NKeys))
                        , HP.attr (H.AttrName "width") "800"
                        , HP.id "keyboard"
                        ]
                        []
                    ]
                , if not audioStarted then
                    HH.button
                      [ classes [ "text-2xl", "m-5", "bg-indigo-500", "p-3", "rounded-lg", "text-white", "hover:bg-indigo-400" ], HE.onClick \_ -> StartAudio ]
                      [ HH.text "Start audio" ]
                  else
                    HH.button
                      ([ classes [ "text-2xl", "m-5", "bg-pink-500", "p-3", "rounded-lg", "text-white", "hover:bg-pink-400" ] ] <> if canStopAudio then [ HE.onClick \_ -> StopAudio ] else [])
                      [ HH.text "Stop audio" ]
                ]
            , HH.div [ classes [ "flex-grow" ] ] []
            ]
        , HH.div [ classes [ "flex-grow" ] ] []
        ]
    ]

makeOsc
  :: ∀ m s
   . MonadEffect m
  => Pos s
  => AudioContext
  -> (V.Vec s Number) /\ (V.Vec s Number)
  -> m BrowserPeriodicWave
makeOsc ctx o =
  H.liftEffect
    $ makePeriodicWave ctx (fst o) (snd o)

easingAlgorithm :: Cofree ((->) Int) Int
easingAlgorithm =
  let
    fOf initialTime = initialTime :< \adj -> fOf $ max 15 (initialTime - adj)
  in
    fOf 15

foreign import cachedScene
  :: Maybe Types.Wag -> (Types.Wag -> Maybe Types.Wag) -> Effect (Maybe Types.Wag)

foreign import storeWag :: Foreign

foreign import cachedStash :: forall buffers floatArrays periodicWaves. Maybe (StashedSig buffers floatArrays periodicWaves) -> (StashedSig buffers floatArrays periodicWaves -> Maybe (StashedSig buffers floatArrays periodicWaves)) -> Effect (Maybe (StashedSig buffers floatArrays periodicWaves))

foreign import storeStash :: Foreign

oe :: forall a b. (a -> b -> Boolean) -> (a -> Aff b) -> Object a -> Object b -> Aff (Object b)
oe isEq trans template current = O.union <$> (sequential (sequence (map (parallel <<< trans) newStuff))) <*> pure filtered
  where
  -- things from the old to keep. as the above operation is left biased
  -- it will ignore anything in newStuff
  filtered = O.filterKeys (flip O.member template) current

  -- if it is not in current, then it is new
  -- if it is not eq, then it is new
  newStuff = O.filterWithKey (\k v -> maybe true (\v' -> not (isEq v v')) (O.lookup k current)) template

stashBehavior :: forall a b. Ref.Ref a -> (a -> b) -> Behavior b
stashBehavior internalStashRef f =
  behavior \eAToB ->
    makeEvent \fB ->
      subscribe eAToB \aToB -> Ref.read internalStashRef >>= fB <<< aToB <<< f

arrrr :: Array ~> Array
arrrr = identity

toMap :: forall a. Object a -> Map String a
toMap = Map.fromFoldable <<< arrrr <<< O.toUnfoldable

fromMap :: forall a. Map String a -> Object a
fromMap = O.fromFoldable <<< arrrr <<< Map.toUnfoldable

unsafeCoerceStash :: forall a b c d e f. Stash { | a } { | b } { | c } -> Stash { | d } { | e } { | f }
unsafeCoerceStash = unsafeCoerce

handleAction :: forall output m. MonadEffect m => MonadAff m => Action -> H.HalogenM State Action () output m Unit
handleAction = case _ of
  Initialize -> do
    musicRef <- H.liftEffect $ Ref.new initialMusic
    let
      lzs = lenses musicRef
    _ <-
      H.liftEffect
        $ sequence
        $ mapWithIndex (\i a -> knobCb ("knob" <> show (i + 1)) a) lzs.knobs
    _ <-
      H.liftEffect
        $ sequence
        $ mapWithIndex (\i a -> sliderCb ("slider" <> show (i + 1)) a) lzs.sliders
    _ <-
      H.liftEffect
        $ sequence
        $ mapWithIndex (\i a -> switchCb ("switch" <> show (i + 1)) a) lzs.switches
    _ <- H.liftEffect $ keyboardCb "keyboard" (V.toArray lzs.keyboard)
    H.modify_ _ { musicRef = Just musicRef }
  UpdateStashInfo s -> H.modify_ _ { stashInfo = s }
  StartAudio -> do
    handleAction StopAudio
    H.modify_ _ { audioStarted = true, canStopAudio = false }
    { microphone } <- H.liftAff $ getMicrophoneAndCamera true false
    musicRef <-
      H.gets _.musicRef
        >>= case _ of
          Nothing -> H.liftEffect $ throwError (error "Cannot get music ref")
          Just x -> pure x
    -- for now, this is completely unsafe as the type safety is managed in the live coding session
    -- may be worth it to make this a bit safer
    behaviorStashRef <- H.liftEffect $ Ref.new $ unsafeCoerceStash $ Stash
      { buffers: {}
      , floatArrays: {}
      , periodicWaves: {}
      }
    { emitter, listener } <- H.liftEffect HS.create
    unsubscribeFromHalogen <- H.subscribe emitter
    { ctx, unsubscribeFromWags, unsubscribeFromStash } <-
      H.liftAff do
        ctx <- H.liftEffect context
        (internalStashRef :: Ref.Ref CacheStash) <- H.liftEffect $ Ref.new $ Stash { buffers: O.empty, periodicWaves: O.empty, floatArrays: O.empty }
        unsubscribeFromStash <-
          H.liftEffect
            $ subscribe (cs <|> stash) \stashMaker -> launchAff_ do
                oldStash <- H.liftEffect $ Ref.read internalStashRef
                -- Aff { cache :: CacheStash, stash :: Stash { | buffers } { | floatArrays } { | periodicWaves } }
                stashFromMaker <- stashMaker ctx oldStash
                H.liftEffect $ Ref.write stashFromMaker.cache internalStashRef
                H.liftEffect $ Ref.write (unsafeCoerceStash stashFromMaker.stash) behaviorStashRef
                H.liftEffect
                  ( HS.notify listener $ UpdateStashInfo
                      { buffers: O.keys (unwrap stashFromMaker.cache).buffers
                      , floatArrays: O.keys (unwrap stashFromMaker.cache).floatArrays
                      , periodicWaves: O.keys (unwrap stashFromMaker.cache).periodicWaves
                      }
                  )

        unitCache <- H.liftEffect makeUnitCache
        let
          ffiAudio = defaultFFIAudio ctx unitCache
        mouse <- H.liftEffect getMouse
        unsubscribeFromWags <-
          H.liftEffect do
            maybeWag <- cachedScene Nothing Just
            subscribe
              ( run
                  ( pure Types.InitialEvent
                      <|> (Types.HotReload <$> wag)
                      <|> (Types.MouseDown <$> Mouse.down)
                      <|> (Types.MouseUp <$> Mouse.up)
                      <|> (Types.KeyboardDown <$> Keyboard.down)
                      <|> (Types.KeyboardUp <$> Keyboard.up)
                  )
                  (R.union <$> ({ mousePosition: _, stash: _ } <$> position mouse <*> ref2Behavior behaviorStashRef) <*> ref2Behavior musicRef)
                  { easingAlgorithm }
                  ffiAudio
                  (fromMaybe piece ((\(Types.Wag wg) -> fst wg) <$> maybeWag))
              )
              (\(_ :: Run Unit ()) -> pure unit) -- (Log.info <<< show)
        pure { ctx, unsubscribeFromWags, unsubscribeFromStash }
    H.modify_
      _
        { unsubscribe =
            do
              unsubscribeFromWags
              unsubscribeFromStash
        , audioCtx = Just ctx
        , canStopAudio = true
        , unsubscribeFromHalogen = Just unsubscribeFromHalogen
        }
  StopAudio -> do
    { unsubscribe, unsubscribeFromHalogen, audioCtx } <- H.get
    for_ unsubscribeFromHalogen H.unsubscribe
    H.liftEffect unsubscribe
    for_ audioCtx (H.liftEffect <<< close)
    H.modify_ _ { unsubscribe = pure unit, audioCtx = Nothing, audioStarted = false, canStopAudio = false }
