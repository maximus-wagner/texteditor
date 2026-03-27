;;;; ui/cursor.lisp -- Blinking cursor component
;;;;
;;;; This module provides a cursor component that renders a blinking cursor.

(defpackage :ui.cursor
  (:use :cl))

(in-package :ui.cursor)

(defparameter +height+ 16)
(defparameter +period-ms+ 1000)

(defclass cursor ()
  ((midpoint :accessor midpoint)
   (period-start :initform (sdl:get-ticks) :accessor period-start)))
(export 'cursor)
(export 'midpoint)

(defgeneric render (cursor))
(export 'render)

(defmethod render ((c cursor))
  (when (> (- (sdl:get-ticks) (period-start c)) +period-ms+)
    (setf (period-start c) (sdl:get-ticks)))
  (when (< (- (sdl:get-ticks) (period-start c)) (/ +period-ms+ 2))
    (sdl:set-render-draw-color *renderer* '(#xee #xee #xee #xff))
    (sdl:render-fill-rect
     *renderer*
     (list (car (midpoint c)) (- (cadr (midpoint c)) (/ +height+ 2)) 2 +height+))))
