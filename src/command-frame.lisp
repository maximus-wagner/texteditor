(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :command-frame)
    (defpackage :command-frame
      (:use :cl :state :utils)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :command-frame)

(defvar *show* nil)

(defun show ()
  (fmteo "command-frame~%")
  (setf *show* t))
(export 'show)

(defun reset ()
  (setf *show* nil))

(defun render ()
  (when *show*
    (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
      (sdl:set-render-draw-color *renderer* '(#x11 #x11 #x11 #xff))
      (sdl:render-rect *renderer* (list 10 (- rh 30) (- rw 20) 20))
      (sdl:set-render-draw-color *renderer* '(#x44 #x44 #x44 #xff))
      (sdl:render-fill-rect *renderer* (list 11 (- rh 29) (- rw 22) 18)))))
(export 'render)

(defun handle-key (key)
  (when (= key (char-code #\Esc))
    (reset)))
(export 'handle-key)
