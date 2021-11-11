module WAGSI.LiveCodeHere.Wagged where

import WAGS.Lib.Tidal.Tidal (make, s)
import WAGSI.Plumbing.Types (WhatsNext)

wag :: WhatsNext
wag =
  make 1.0
    { earth: s "bassdm <hh [hh hh hh hh]> [bassdm:2 bassdm:2] hh27"
    , title: "i m a k e n o i s e"
    }
