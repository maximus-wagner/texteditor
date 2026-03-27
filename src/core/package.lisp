;;;; core/package.lisp -- Core package definition
;;;;
;;;; This package contains the foundational elements of the text editor:
;;;; - SDL3 bindings (sdl.lisp)
;;;; - Application state (state.lisp)
;;;; - Utility functions (utils.lisp)

(defpackage :core
  (:use :cl))

(in-package :core)

;; Load dependencies in order
(load "src/deps.lisp")
(load "src/core/sdl-bindings.lisp")
(load "src/core/state.lisp")
(load "src/core/utils.lisp")
