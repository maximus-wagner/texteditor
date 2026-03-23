(load (merge-pathnames #p"quicklisp/setup.lisp" (user-homedir-pathname)))
(ql:quickload '(:cffi :cffi-libffi))

;; (do-external-symbols (sym :sdl3) (print sym))

(load "src/sdl.lisp")
(load "src/state.lisp")
(load "src/cursor.lisp")
(load "src/utils.lisp")
(load "src/command-frame.lisp")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :main)
    (defpackage :main
      (:use :cl :state :utils)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :main)
(require 'uiop)

(defparameter *running* t)

(defun handle-quit (event)
  (declare (ignore event))
  (format t "Got SDL Quit event~%")
  (setf *running* nil))

(defun handle-key-down (event)
  (let ((key (sdl:get-key-from-scancode
              (sdl:keyboard-event-scancode event)
              (sdl:keyboard-event-mod event)
              nil)))
    (fmteo "key: ~a~%" key)
    (command-frame:handle-key key)
    (when (= key (char-code #\:))
      (command-frame:show))
    (when (= key (char-code #\q))
      (setf *running* nil))))

(defun handle-text-input (event)
  (fmteo "got text input event~%")
  (let ((text (sdl:text-input-event-text event)))
    (fmteo "got text input: ~a~%" text)))

(defstruct fps-state
  (frames 0 :type fixnum)
  (window-start 0 :type (unsigned-byte 64))
  (fps 0.0 :type single-float))

(defun make-fps ()
  (make-fps-state :window-start (sdl:get-ticks)))

(defun fps-tick (s)
  "Call once per frame. Returns updated FPS when the window rolls over, nil otherwise."
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

(defun render-state ()
  (when (not *fps*)
    (setf *fps* (make-fps)))
  (when (fps-tick *fps*)
    (setf *last-fps* (fps-state-fps *fps*)))

  (sdl:set-render-draw-color *renderer* '(#x33 #x33 #x33 #xff))
  (sdl:render-clear *renderer*)
  (when *last-fps*
    (let ((texture (create-texture-from-text
                    (format nil "~d FPS" (round *last-fps*)))))
      (destructuring-bind (w h) (sdl:get-texture-size texture)
        (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
          (sdl:render-texture *renderer* texture nil (list (- rw w 4) (- rh h) w h))))
      (sdl:destroy-texture texture)))
  (command-frame:render)
  (sdl:render-present *renderer*))

(defun loop-events ()
  (loop while *running*
        do (cffi:with-foreign-object (event :uint8 sdl:+event-size+)
             (loop while (and *running* (sdl:poll-event event))
                   do (case (sdl:event-type event)
                        (:quit (handle-quit event))
                        (:key-down (handle-key-down event))
                        (:text-input (handle-text-input event))
                        (otherwise (fmteo "unknown event ~a~%" (sdl:event-type event))))))
        (render-state)
        ))

(defun main ()
  (sdl:init '(:video :events))
  (fmteo "SDL version: ~a, revision: ~a~%" (sdl:get-version) (sdl:get-revision))
  (fmteo "SDL-TTF version: ~a~%" (sdl:ttf-version))
  (fmteo "Forcing Vulkan render driver~%") 
  (sdl:set-hint "SDL_RENDER_DRIVER" "vulkan") ; opengl software
  (sdl:ttf-init)
  (multiple-value-bind (rst window *renderer*)
      (sdl:create-window-and-renderer "Text Editor Window" 500 500 '(:resizable))
    (if rst
        (progn
          (destructuring-bind (w h) (sdl:get-render-output-size *renderer*)
            (format t "render size: ~ax~a~%" w h))
          (format t "renderer: ~a~%" (sdl:get-renderer-name *renderer*))
          (format t "video driver: ~a~%" (sdl:get-current-video-driver))

          (loop-events)
          (format t "loop-events returned~%")
          (sdl:destroy-renderer *renderer*)
          (sdl:destroy-window window))
        (format *error-output* "SDL Error: ~a~%" (sdl:get-error)))
    (sdl:ttf-quit)
    (sdl:quit)))
(export 'main)
