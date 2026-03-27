;;;; ui/command-frame.lisp -- Command-line interface frame
;;;;
;;;; This module provides a command frame that appears at the bottom of
;;;; the screen when the user presses Insert.

(defpackage :ui.command-frame
  (:use :cl))

(in-package :ui.command-frame)

(defvar *show* nil)
(defvar *input-text* "")
(defparameter *show-fps* nil)

(defparameter +cursor-height+ 16)
(defparameter +cursor-period-ms+ 1000)
(defparameter +cursor-start+ 0)
(defparameter +cursor-x+ 12)

(defun show (&optional (prefix ""))
  (fmteo "command-frame~%")
  (setf *show* t)
  (setf *input-text* prefix)
  (setf +cursor-start+ (sdl:get-ticks)))

(defun reset ()
  (setf *show* nil)
  (setf *input-text* ""))

(defun render ()
  (when *show*
    (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
      (sdl:set-render-draw-color *renderer* '(#x11 #x11 #x11 #xff))
      (sdl:render-rect *renderer* (list 10 (- rh 30) (- rw 20) 20))
      (sdl:set-render-draw-color *renderer* '(#x44 #x44 #x44 #xff))
      (sdl:render-fill-rect *renderer* (list 11 (- rh 29) (- rw 22) 18))
      (let ((tx (create-texture-from-text (format "/~a" *input-text*))))
        (destructuring-bind (w h) (sdl:get-texture-size tx)
          (sdl:render-texture *renderer* tx nil (list 12 (- rh 29 -9 (/ h 2)) w h))
          (setf +cursor-x+ (+ 12 w)))
        (sdl:destroy-texture tx))
      ;; Render blinking cursor
      (when (> (- (sdl:get-ticks) +cursor-start+) +cursor-period-ms+)
        (setf +cursor-start+ (sdl:get-ticks)))
      (when (< (- (sdl:get-ticks) +cursor-start+) (/ +cursor-period-ms+ 2))
        (sdl:set-render-draw-color *renderer* '(#xee #xee #xee #xff))
        (sdl:render-fill-rect
         *renderer*
         (list +cursor-x+ (- rh 29 -9 (/ +cursor-height+ 2)) 2 +cursor-height+))))))

(defun handle-key (key)
  (cond
    ((= key (char-code #\Esc))
     (reset))
    ((= key (char-code #\Return))
     (execute-command))
    ((= key (char-code #\Backspace))
     (when (> (length *input-text*) 0)
       (setf *input-text* (subseq *input-text* 0 (1- (length *input-text*))))))))

(defun execute-command ()
  (let* ((raw *input-text*)
         (cmd (string-downcase raw))
         (parts (uiop:split-string cmd :separator (list #\Space))))
    (cond
     ((string= cmd "/fps")
      (setf *show-fps* (not *show-fps*))
      (fmteo "FPS counter: ~a~%" *show-fps*)
      (reset))
     ((string= cmd "/quit")
      (main:set-running nil)
      (reset))
     ((and (string= (first parts) "/font")
           (>= (length raw) 7))
      ;; Everything after "/font " is the font path
      (let ((path (string-trim '(#\Space) (subseq raw 6))))
        (if (and path (> (length path) 0))
            (if (state:set-font path)
                (progn
                  (fmteo "Font set: ~a~%" path)
                  (reset))
                (progn
                  (fmteo "Font not found: ~a~%" path)
                  (reset)))
            (progn
              (fmteo "Usage: /font <path-to-ttf>~%")
              (reset)))))
     (t
      (fmteo "Unknown command: ~a~%" *input-text*)
      (reset)))))

(defun handle-text (text)
  (when *show*
    (setf *input-text* (concatenate 'string *input-text* text))))

(defun get-show-fps ()
  *show-fps*)

(export 'get-show-fps)
(export 'show)
(export 'reset)
(export 'render)
(export 'handle-key)
(export 'handle-text)
