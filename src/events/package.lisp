;;;; events/package.lisp -- Event handling package
;;;;
;;;; This package handles SDL events and dispatches them to appropriate handlers.

(defpackage :events
  (:use :cl :core :core.state :core.utils))

(in-package :events)

;; Global flag controlling the main loop
(defparameter *running* t)
(export '*running*)

(defun set-running (value)
  (setf *running* value))
(export 'set-running)

;;; Event Handlers ;;;

(defun handle-quit (event)
  (declare (ignore event))
  (format t "Got SDL Quit event~%")
  (setf *running* nil))

(defun handle-key-down (event)
  (let* ((scancode (sdl:keyboard-event-scancode event))
         (key (sdl:get-key-from-scancode
               scancode
               (sdl:keyboard-event-mod event)
               nil)))
    (fmteo "key: ~a, scancode: ~a~%" key scancode)
    ;; Dispatch key to UI components
    (ui:handle-key key)
    ;; Insert key opens command frame
    (when (= scancode 73)
      (ui:show-command-frame))
    ;; Press F1 to quit (scancode 0x3A = 58)
    (when (= scancode 58)
      (setf *running* nil))))

(defun handle-text-input (event)
  (fmteo "got text input event~%")
  (let ((text (sdl:text-input-event-text event)))
    (fmteo "got text input: ~a~%" text)
    ;; Dispatch text to UI
    (ui:handle-text text)))

;;; Event Loop ;;;

(defun event-dispatch (event)
  (case (sdl:event-type event)
    (:quit (handle-quit event))
    (:key-down (handle-key-down event))
    (:text-input (handle-text-input event))
    (otherwise (fmteo "unknown event ~a~%" (sdl:event-type event)))))

(export 'event-dispatch)

(defun poll-events ()
  (cffi:with-foreign-object (event :uint8 sdl:+event-size+)
    (loop while (sdl:poll-event event)
          do (event-dispatch event)
          until (not *running*))))

(export 'poll-events)
