;;;; renderer/package.lisp -- Rendering package
;;;;
;;;; This package handles rendering operations including the FPS counter.

(defpackage :renderer
  (:use :cl :core :core.state :core.utils))

(in-package :renderer)

;;; FPS Counter ;;;

(defstruct fps-state
  (frames 0 :type fixnum)
  (window-start 0 :type (unsigned-byte 64))
  (fps 0.0 :type single-float))

(defun make-fps ()
  (make-fps-state :window-start (sdl:get-ticks)))

(defun fps-tick (s)
  (incf (fps-state-frames s))
  (let* ((now (sdl:get-ticks))
         (elapsed (- now (fps-state-window-start s))))
    (when (>= elapsed 1000)
      (setf (fps-state-fps s) (/ (* (fps-state-frames s) 1000.0) elapsed))
      (setf (fps-state-frames s) 0)
      (setf (fps-state-window-start s) now)
      (fps-state-fps s))))

(defparameter *fps* nil)
(defparameter *last-fps* nil)

;;; Main Render Function ;;;

(defparameter *fps-visible* nil)

(defun render ()
  (when (not *fps*)
    (setf *fps* (make-fps)))
  (when (fps-tick *fps*)
    (setf *last-fps* (fps-state-fps *fps*)))

  (sdl:set-render-draw-color *renderer* '(#x33 #x33 #x33 #xff))
  (sdl:render-clear *renderer*)
  (when (and *last-fps* (ui.command-frame:get-show-fps))
    (let ((texture (create-texture-from-text
                    (format nil "~d FPS" (round *last-fps*)))))
      (destructuring-bind (w h) (sdl:get-texture-size texture)
        (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
          (sdl:render-texture *renderer* texture nil (list (- rw w 4) (- rh h) w h))))
      (sdl:destroy-texture texture)))
  (sdl:render-present *renderer*))

(export 'render)
