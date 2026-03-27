;;;; core/utils.lisp -- Utility functions
;;;;
;;;; Helper functions for formatting and text rendering.

(defpackage :core.utils
  (:use :cl))

(in-package :core.utils)

(defun fmteo (&rest args)
  (apply #'format *error-output* args))
(export 'fmteo)

(defun create-texture-from-text (text)
  (sdl:create-texture-from-surface
   *renderer*
   (sdl:ttf-render-text-blended (get-font) text '(#xee #xee #xee #xff))))
(export 'create-texture-from-text)
