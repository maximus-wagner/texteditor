(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :command-frame)
    (defpackage :command-frame
      (:use :cl :state :utils)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :command-frame)

(defvar *show* nil)
(defparameter *cursor* (make-instance 'cursor:cursor))

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
      (sdl:render-fill-rect *renderer* (list 11 (- rh 29) (- rw 22) 18))
      (let ((tx (create-texture-from-text ":")))
        (destructuring-bind (w h) (sdl:get-texture-size tx)
          ;; (fmteo "height: ~a, ~a~%" h (- rh 29 -9 (/ h 2)))
          (sdl:render-texture *renderer* tx nil (list 12 (- rh 29 -9 (/ h 2)) w h))
          (setf (cursor:midpoint *cursor*) (list (+ 12 w) (- rh 29 -9))))
        (sdl:destroy-texture tx))
      (cursor:render *cursor*))))
        
(export 'render)

(defun handle-key (key)
  (when (= key (char-code #\Esc))
    (reset)))
(export 'handle-key)
