;;;; core/state.lisp -- Global application state

(defpackage :core.state
  (:use :cl :sdl))

(in-package :core.state)

(defparameter *renderer* nil)
(export '*renderer*)

(defparameter *font-size-px* 16.0)
(defparameter *font* nil)

(defparameter *font-paths*
  (list
   ;; 1. Project-local assets directory
   "assets/Px437_ATI_8x16.ttf"
   ;; 2. User's fonts directory
   (merge-pathnames #p"AppData/Local/Microsoft/Windows/Fonts/Px437_ATI_8x16.ttf"
                    (user-homedir-pathname))
   ;; 3. System monospace fonts (cross-platform fallbacks)
   "C:/Windows/Fonts/consola.ttf"
   "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
   "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"
   "/System/Library/Fonts/Menlo.ttc"
   "C:/Windows/Fonts/cour.ttf"))

(defun find-font-file ()
  "Search *font-paths* for the first font file that exists."
  (dolist (path *font-paths* nil)
    (let ((resolved (probe-file path)))
      (when resolved
        (return resolved)))))

(defun get-font ()
  (when (not *font*)
    (let ((path (find-font-file)))
      (if path
          (progn
            (setf *font* (sdl:ttf-open-font (namestring path) *font-size-px*))
            (format *error-output* "Loaded font: ~a~%" path))
          (format *error-output* "Warning: no font found~%"))))
  *font*)
(export 'get-font)

(defun set-font (path)
  "Load a new font from PATH. Returns T on success, NIL on failure."
  (when (probe-file path)
    (when *font*
      (sdl:ttf-close-font *font*))
    (setf *font* (sdl:ttf-open-font (namestring path) *font-size-px*))
    t))
(export 'set-font)
