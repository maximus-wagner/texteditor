;;;; entry.lisp -- Main entry point for the text editor
;;;;
;;;; This is the main entry point that initializes SDL and runs the application.
;;;; Load this file to start the text editor.

;; Load dependencies first
(load "src/deps.lisp")

;; Load core modules
(load "src/core/sdl-bindings.lisp")
(load "src/core/state.lisp")
(load "src/core/utils.lisp")

;; Load UI modules
(load "src/ui/cursor.lisp")
(load "src/ui/command-frame.lisp")
(load "src/ui/package.lisp")

;; Load renderer
(load "src/renderer/package.lisp")

;; Load event handling
(load "src/events/package.lisp")

;; Define the main package
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :entry)
    (defpackage :entry
      (:use :cl :core :core.state :core.utils :ui :renderer :events))))
(in-package :entry)

(require 'uiop)

;;; Main Entry Point ;;;

(defun main ()
  "Initialize SDL3 and run the text editor application."
  (sdl:init '(:video :events))
  (fmteo "SDL version: ~a, revision: ~a~%" (sdl:get-version) (sdl:get-revision))
  (fmteo "SDL-TTF version: ~a~%" (sdl:ttf-version))
  (fmteo "Forcing Vulkan render driver~%")
  (sdl:set-hint "SDL_RENDER_DRIVER" "vulkan")
  (sdl:ttf-init)
  
  (multiple-value-bind (rst window *renderer*)
      (sdl:create-window-and-renderer "Text Editor Window" 500 500 '(:resizable))
    (if rst
        (progn
          (destructuring-bind (w h) (sdl:get-render-output-size *renderer*)
            (format t "render size: ~ax~a~%" w h))
          (format t "renderer: ~a~%" (sdl:get-renderer-name *renderer*))
          (format t "video driver: ~a~%" (sdl:get-current-video-driver))
          (main-loop))
        (format *error-output* "SDL Error: ~a~%" (sdl:get-error)))
    (sdl:ttf-quit)
    (sdl:quit)))

(defun main-loop ()
  "Main event and render loop."
  (loop while *running*
        do (poll-events)
        do (renderer:render)
        do (ui:render)))

(export 'main)
