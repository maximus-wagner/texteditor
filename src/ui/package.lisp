;;;; ui/package.lisp -- UI package combining all UI components
;;;;
;;;; This package combines cursor, command-frame, and other UI components
;;;; into a unified UI system.

(defpackage :ui
  (:use :cl :core :core.state :core.utils :ui.cursor))

(in-package :ui)

;; Load UI components
(load "src/ui/cursor.lisp")
(load "src/ui/command-frame.lisp")

;; Command frame visibility
(defvar *command-frame-visible* nil)
(export '*command-frame-visible*)

(defun show-command-frame ()
  (setf *command-frame-visible* t)
  (command-frame:show))

(defun hide-command-frame ()
  (setf *command-frame-visible* nil)
  (command-frame:reset))

(defun handle-key (key)
  "Handle key events for UI components.
   Returns T if handled, NIL otherwise."
  (command-frame:handle-key key))

(defun handle-text (text)
  "Handle text input for UI components."
  (command-frame:handle-text text))

;;; Render all UI components ;;;

(defun render ()
  "Render all UI components."
  (command-frame:render))

(export 'render)
(export 'show-command-frame)
(export 'hide-command-frame)
(export 'handle-key)
(export 'handle-text)
