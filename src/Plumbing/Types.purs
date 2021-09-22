module WAGSI.Plumbing.Types where

import Prelude

import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Tuple.Nested (type (/\))
import Data.Typelevel.Num (D10, D48)
import Data.Vec as V
import WAGS.Control.Types (Scene, WAG)
import WAGS.Interpret (class AudioInterpret)
import WAGS.Run (SceneI)

newtype Wag
  = Wag
  ( forall buffers floatArrays periodicWaves audio engine proof res graph control
     . Monoid res
    => AudioInterpret audio engine
    => Scene (Extern buffers floatArrays periodicWaves) audio engine proof res
         /\
           ( Extern buffers floatArrays periodicWaves
             -> WAG audio engine proof res graph control
             -> Scene (Extern buffers floatArrays periodicWaves) audio engine proof res
           )
  )

data Evt
  = InitialEvent
  | HotReload Wag
  | MouseDown Int
  | MouseUp Int
  | KeyboardDown String
  | KeyboardUp String

type NKnobs
  = D10

type NSliders
  = D10

type NSwitches
  = D10

type NKeys
  = D48

type Music' knobs sliders switches keyboard
  =
  ( knobs :: V.Vec NKnobs knobs
  , sliders :: V.Vec NKnobs sliders
  , switches :: V.Vec NKnobs switches
  , keyboard :: V.Vec NKeys keyboard
  )

newtype Stash buffers floatArrays periodicWaves = Stash
  { buffers :: buffers
  , floatArrays :: floatArrays
  , periodicWaves :: periodicWaves
  }

derive instance newtypeStash :: Newtype (Stash buffers floatArrays periodicWaves) _

type Music
  = Music' Number Number Boolean Boolean

type Wld buffers floatArrays periodicWaves
  =
  { mousePosition :: Maybe { x :: Int, y :: Int }
  , stash :: Stash { | buffers } { | floatArrays } { | periodicWaves }
  | Music
  }

type Extern buffers floatArrays periodicWaves
  = SceneI Evt (Wld buffers floatArrays periodicWaves) ()
