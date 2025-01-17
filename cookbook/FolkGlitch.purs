module WAGSI.Cookbook.FolkGlitch where

import Prelude

import Data.Either (Either(..))
import Data.Lens (set)
import Data.Profunctor (lcmap)
import WAGS.Lib.Tidal.Samples (initialEntropy)
import WAGS.Lib.Tidal.Samples as S
import WAGS.Lib.Tidal.Tidal (lns, lnv, make, onTag, parse_, s)
import WAGSI.Plumbing.Types (WhatsNext)

wag :: WhatsNext
wag = make 1.0
  { earth: s
      $ onTag "tb"
          ( map
              $ compose
                  (set lnv $ lcmap initialEntropy ((>) 0.5 >>> if _ then 0.0 else 1.0))
                  (set lns $ Left $ lcmap initialEntropy ((>) 0.5 >>> if _ then S.tabla_0__Sample else S.tabla2_0__Sample))
          )
      $ parse_ "bassdm <chin*4 psr> tabla;tb ~"
  , title: "Tabla + glitch"
  , preload: [S.tabla_0__Sample, S.tabla2_0__Sample]
  }