(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :utils)
    (defpackage :utils
      (:use :cl :state)
      )))
(in-package :utils)

(defun fmteo (&rest args)
  (apply #'format *error-output* args))
(export 'fmteo)

(defvar *box-h* nil)  ; horizontal line char
(defvar *box-v* nil)  ; vertical line char
(defvar *box-tl* nil) ; top-left corner
(defvar *box-tr* nil) ; top-right corner
(defvar *box-bl* nil) ; bottom-left corner
(defvar *box-br* nil) ; bottom-right corner
(defvar *box-ml* nil) ; middle-left T
(defvar *box-mr* nil) ; middle-right T

(defun char-renders-p (ch)
  "Return T if CH renders to a visible glyph."
  (let ((tx (sdl:create-texture-from-surface
             *renderer*
             (sdl:ttf-render-text-blended (get-font) (string ch) '(#xee #xee #xee #xff)))))
    (when tx
      (destructuring-bind (w h) (sdl:get-texture-size tx)
        (declare (ignore h))
        (sdl:destroy-texture tx)
        (and w (> w 0))))))

(defun init-box-drawing ()
  "Use ASCII box-drawing characters (reliable across all fonts)."
  (setf *box-h*  #\-  *box-v*  #\|
        *box-tl* #\+  *box-tr* #\+
        *box-bl* #\+  *box-br* #\+
        *box-ml* #\|  *box-mr* #\|))
(export 'init-box-drawing)
(export '(*box-h* *box-v* *box-tl* *box-tr* *box-bl* *box-br* *box-ml* *box-mr*))

;;; Scrollbar chars
(defvar *sb-up*    "^")
(defvar *sb-dn*    "v")
(defvar *sb-track* ":")
(defvar *sb-thumb* "#")
(export '(*sb-up* *sb-dn* *sb-track* *sb-thumb*))

(defun box-hline (n)
  "Return a horizontal line of N characters."
  (make-string (max 0 n) :initial-element *box-h*))
(export 'box-hline)

(defun str-pad-right (str width)
  "Pad or truncate STR to exactly WIDTH characters."
  (let ((n (length str)))
    (cond ((= n width) str)
          ((> n width) (subseq str 0 width))
          (t (concatenate 'string str (make-string (- width n) :initial-element #\Space))))))
(export 'str-pad-right)

(defun box-row (content cols)
  "Return exactly COLS chars: left-border + content padded to (cols-2) + right-border."
  (concatenate 'string
               (string *box-v*)
               (str-pad-right content (- cols 2))
               (string *box-v*)))
(export 'box-row)

(defun create-texture-from-text (text)
  (sdl:create-texture-from-surface
   *renderer* 
   (sdl:ttf-render-text-blended (get-font) text '(#xee #xee #xee #xff))))
(export 'create-texture-from-text)

(defun create-texture-from-text-colored (text rgba)
  "Create a text texture with RGBA color list, e.g. '(#x88 #x88 #x88 #xff)."
  (sdl:create-texture-from-surface
   *renderer*
   (sdl:ttf-render-text-blended (get-font) text rgba)))
(export 'create-texture-from-text-colored)
