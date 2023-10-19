#!/usr/bin/env gxi
;; -*- Gerbil -*-
;; This is the main build file for Gerbil-ethereum. Invoke it using
;; ./build.ss [cmd]
;; where [cmd] is typically left empty (same as "compile")
;; Note that may you need to first:
;;   for i in github.com/fare/gerbil-utils github.com/fare/gerbil-crypto github.com/fare/gerbil-poo github.com/fare/gerbil-persist ; do gxpkg install $i ; done

(displayln "Building heroku-example-gerbil")

(import :clan/building :clan/multicall)

(displayln "foo 100")

(def (files)
  (displayln "foo 250")
  [(all-gerbil-modules)...
   [exe: "main.ss" bin: "heroku-example-gerbil"]])

(displayln "foo 200")

(def main
  (let ()
    (init-build-environment!
     name: "heroku-example-gerbil"
     deps: '("clan")
     spec: files)
    (lambda x (displayln "foo 400") (begin0 (apply main x) (displayln "foo 999")))))

(displayln "foo 300")
