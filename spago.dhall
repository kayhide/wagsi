{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "my-project"
, dependencies =
  [ "aff"
  , "aff-promise"
  , "arrays"
  , "behaviors"
  , "canvas"
  , "cartesian"
  , "colors"
  , "console"
  , "control"
  , "convertable-options"
  , "effect"
  , "either"
  , "event"
  , "filterable"
  , "foldable-traversable"
  , "foreign"
  , "foreign-object"
  , "free"
  , "halogen"
  , "halogen-subscriptions"
  , "heterogeneous"
  , "identity"
  , "indexed-monad"
  , "integers"
  , "lcg"
  , "lists"
  , "math"
  , "maybe"
  , "newtype"
  , "nonempty"
  , "ordered-collections"
  , "painting"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "psci-support"
  , "quickcheck"
  , "random"
  , "record"
  , "refs"
  , "safe-coerce"
  , "simple-json"
  , "sized-vectors"
  , "string-parsers"
  , "strings"
  , "transformers"
  , "tuples"
  , "typelevel"
  , "typelevel-peano"
  , "unfoldable"
  , "unsafe-coerce"
  , "wags"
  , "wags-lib"
  , "web-html"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
