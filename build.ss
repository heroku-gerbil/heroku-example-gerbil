#!/usr/bin/env gxi
;; -*- Gerbil -*-
;; This is the main build file for Gerbil-ethereum. Invoke it using
;; ./build.ss [cmd]
;; where [cmd] is typically left empty (same as "compile")
;; Note that may you need to first:
;;   for i in github.com/fare/gerbil-utils github.com/fare/gerbil-crypto github.com/fare/gerbil-poo github.com/fare/gerbil-persist ; do gxpkg install $i ; done

(displayln "Building heroku-example-gerbil")

(import :std/build-script)

(defbuild-script
  `((exe: "main.ss" bin: "heroku-example-gerbil")))

#| ;; Here is how you could do it instead using gerbil-utils:

(import :clan/building :clan/multicall)

(def (files)
  [(all-gerbil-modules)...
   [exe: "main.ss" bin: "heroku-example-gerbil"]])

(init-build-environment!
 name: "heroku-example-gerbil"
 deps: '("clan")
 spec: files)
|#
