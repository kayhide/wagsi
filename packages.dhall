{-
Welcome to your new Dhall package-set!

Below are instructions for how to edit this file for most use
cases, so that you don't need to know Dhall to use it.

## Warning: Don't Move This Top-Level Comment!

Due to how `dhall format` currently works, this comment's
instructions cannot appear near corresponding sections below
because `dhall format` will delete the comment. However,
it will not delete a top-level comment like this one.

## Use Cases

Most will want to do one or both of these options:
1. Override/Patch a package's dependency
2. Add a package not already in the default package set

This file will continue to work whether you use one or both options.
Instructions for each option are explained below.

### Overriding/Patching a package

Purpose:
- Change a package's dependency to a newer/older release than the
    default package set's release
- Use your own modified version of some dependency that may
    include new API, changed API, removed API by
    using your custom git repo of the library rather than
    the package set's repo

Syntax:
where `entityName` is one of the following:
- dependencies
- repo
- version
-------------------------------
let upstream = --
in  upstream
  with packageName.entityName = "new value"
-------------------------------

Example:
-------------------------------
let upstream = --
in  upstream
  with halogen.version = "master"
  with halogen.repo = "https://example.com/path/to/git/repo.git"

  with halogen-vdom.version = "v4.0.0"
-------------------------------

### Additions

Purpose:
- Add packages that aren't already included in the default package set

Syntax:
where `<version>` is:
- a tag (i.e. "v4.0.0")
- a branch (i.e. "master")
- commit hash (i.e. "701f3e44aafb1a6459281714858fadf2c4c2a977")
-------------------------------
let upstream = --
in  upstream
  with new-package-name =
    { dependencies =
       [ "dependency1"
       , "dependency2"
       ]
    , repo =
       "https://example.com/path/to/git/repo.git"
    , version =
        "<version>"
    }
-------------------------------

Example:
-------------------------------
let upstream = --
in  upstream
  with benchotron =
      { dependencies =
          [ "arrays"
          , "exists"
          , "profunctor"
          , "strings"
          , "quickcheck"
          , "lcg"
          , "transformers"
          , "foldable-traversable"
          , "exceptions"
          , "node-fs"
          , "node-buffer"
          , "node-readline"
          , "datetime"
          , "now"
          ]
      , repo =
          "https://github.com/hdgarrood/purescript-benchotron.git"
      , version =
          "v7.0.0"
      }
-------------------------------
-}
let upstream =
      https://github.com/purescript/package-sets/releases/download/psc-0.14.4-20210919/packages.dhall sha256:03516fdd4f6d1bd6c9eb5e63cf3af3037bc079459117ab93eb85b6eb46e258a7

let overrides =
      { arraybuffer =
        { dependencies =
          [ "arraybuffer-types"
          , "arrays"
          , "effect"
          , "float32"
          , "functions"
          , "gen"
          , "maybe"
          , "nullable"
          , "prelude"
          , "tailrec"
          , "uint"
          , "unfoldable"
          ]
        , repo =
            "https://github.com/purescript-contrib/purescript-arraybuffer.git"
        , version = "v12.0.0"
        }
      }

let additions =
      { typelevel-peano =
        { dependencies =
          [ "arrays"
          , "console"
          , "effect"
          , "prelude"
          , "psci-support"
          , "typelevel-prelude"
          , "unsafe-coerce"
          ]
        , repo = "https://github.com/csicar/purescript-typelevel-peano.git"
        , version = "v1.0.1"
        }
      , event =
        { dependencies =
          [ "console"
          , "effect"
          , "filterable"
          , "nullable"
          , "unsafe-reference"
          , "js-timers"
          , "now"
          ]
        , repo = "https://github.com/mikesol/purescript-event.git"
        , version = "v1.4.2"
        }
      , behaviors =
        { dependencies =
          [ "psci-support"
          , "effect"
          , "ordered-collections"
          , "filterable"
          , "nullable"
          , "event"
          , "web-html"
          , "web-events"
          , "web-uievents"
          ]
        , repo = "https://github.com/mikesol/purescript-behaviors.git"
        , version = "v8.1.0"
        }
      , wags =
        { dependencies =
          [ "aff-promise"
          , "arraybuffer-types"
          , "behaviors"
          , "console"
          , "convertable-options"
          , "debug"
          , "effect"
          , "event"
          , "free"
          , "heterogeneous"
          , "indexed-monad"
          , "maybe"
          , "ordered-collections"
          , "profunctor-lenses"
          , "psci-support"
          , "record"
          , "simple-json"
          , "sized-vectors"
          , "transformers"
          , "tuples"
          , "typelevel"
          , "typelevel-peano"
          , "typelevel-prelude"
          ]
        , repo = "https://github.com/mikesol/purescript-wags.git"
        , version = "v0.5.10"
        }
      , free =
        { dependencies =
          [ "catenable-lists"
          , "control"
          , "distributive"
          , "either"
          , "exists"
          , "foldable-traversable"
          , "invariant"
          , "lazy"
          , "maybe"
          , "prelude"
          , "tailrec"
          , "transformers"
          , "tuples"
          , "unsafe-coerce"
          ]
        , repo = "https://github.com/mikesol/purescript-free.git"
        , version = "master"
        }
      , wags-lib =
        { dependencies =
          [ "css"
          , "homogeneous"
          , "halogen-css"
          , "wags"
          , "run"
          , "string-parsers"
          , "strings"
          ]
        , repo = "https://github.com/mikesol/purescript-wags-lib.git"
        , version = "v0.0.46"
        }
      , painting =
        { dependencies =
          [ "canvas"
          , "colors"
          , "console"
          , "effect"
          , "foldable-traversable"
          , "foreign-object"
          , "psci-support"
          , "web-html"
          ]
        , repo = "https://github.com/mikesol/purescript-painting.git"
        , version = "v0.0.0"
        }
      , convertable-options =
        { dependencies = [ "console", "effect", "maybe", "record" ]
        , repo =
            "https://github.com/natefaubion/purescript-convertable-options.git"
        , version = "v1.0.0"
        }
      }

in  upstream // overrides // additions
