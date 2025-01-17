module WAGSI.LiveCodeHere.SitarAndHarmonium where

import Prelude

import Data.Lens (_Just, set, traversed)
import Data.Profunctor (lcmap)
import WAGS.Create.Optionals (highpass, pan)
import WAGS.Lib.Tidal.Cycle (c2d, harmonium, sitar_1)
import WAGS.Lib.Tidal.FX (fx, goodbye, hello)
import WAGS.Lib.Tidal.Samples (clockTime, normalizedBigCycleTime)
import WAGS.Lib.Tidal.Tidal (ldt, ldv, lnr, lnv, make, onTag, parse_, s)
import WAGSI.Plumbing.Types (WhatsNext)
import WAGS.Lib.Learn.Oscillator (lfo)

bells :: Number -> Number
bells t
  | t < 0.25 = 1.2
  | t < 0.5 = 1.8
  | t < 0.75 = 1.5
  | otherwise = 1.1

wag :: WhatsNext
wag = make 1.5
  { earth: s $ onTag "tk" (set (traversed <<< lnr) (lcmap normalizedBigCycleTime bells)) $ parse_ "<tabla tabla:3 tabla> ~ tabla:3 ~ , ~ tink*4;tk ~ ~ , ~ can  "
  , wind: s $ set (traversed <<< _Just <<< lnv) (const 0.2) $ parse_ "~ ~ ~ <newnotes:1 newnotes:2 newnotes:3>"
  , heart: set (_Just <<< ldv) (lcmap clockTime (add 0.2 <<< lfo { phase: 0.0, freq: 0.3, amp: 0.2 })) $ c2d harmonium
  , air: set (traversed <<< ldt)
            (lcmap clockTime \t -> fx
                ( goodbye $ pan (0.0) { myhp: highpass (lfo { phase: 0.0, amp: 2000.0, freq: 0.4 } t + 3000.0) hello }
                )
            )
      $ set (_Just <<< ldv) (lcmap clockTime (add 0.1 <<< lfo { phase: 0.0, freq: 0.1, amp: 0.1 }))
      $ c2d sitar_1
  , title: "sitar and harmonium"
  }