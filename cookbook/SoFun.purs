module WAGSI.Cookbook.SoFun where

import Prelude

import Data.Lens (_Just, set)
import Data.Map as Map
import Data.Newtype (unwrap)
import Data.Profunctor (lcmap)
import Data.Tuple.Nested ((/\))
import WAGS.Lib.Tidal.Tidal (lnr, lnv, make, onTag, parse_, s)
import WAGS.Lib.Tidal.Types (BufferUrl(..), Sample(..))
import WAGSI.Plumbing.Types (WhatsNext)

m2 = 4.0 * 1.0 * 60.0/111.0 :: Number

wag :: WhatsNext
wag =
  make m2 -- 7
    { earth: s "bass:1 msg hh ~ [hh:6 bass:0] msg:2 hh ~, ~ chin*4 ~ ~ ~ tech:0*2 ~ ~ , ~ ~ hh:2 ~ ~ newnotes [~ newnotes:2] ~  , ~ ~ ~ ~ hh:7 ~ ~ tech:2*4 , ~ ~ ~ ~ ~ ~ ~ chin:1*2 , pad:3"
    , wind: s 
      $ onTag "comp" (set (_Just <<< lnv) (lcmap unwrap \{ normalizedLittleCycleTime: t } -> if t < 0.9 then 1.0 else 0.0))
      $ onTag "comp" (set (_Just <<< lnr) (lcmap unwrap \{ initialEntropy: e} -> 0.95 + 0.1 * e))
      -- $ onTag "comp" (set (_Just <<< lnbo) (lcmap initialEntropy \e -> e * 2.0))
      $ parse_ "wdm:1;comp"
    , sounds: Map.fromFoldable $ map (\(a /\ b) -> Sample a /\ BufferUrl b) ["wdm:0" /\ "https://freesound.org/data/previews/332/332741_34095-lq.mp3", "wdm:1" /\ "https://freesound.org/data/previews/332/332740_34095-hq.mp3" ]
    , title: "$0 FUN"
    }

