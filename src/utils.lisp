(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :utils)
    (defpackage :utils
      (:use :cl :state)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :utils)

(defun fmteo (&rest args)
  (apply #'format *error-output* args))
(export 'fmteo)

(defun create-texture-from-text (text)
  (sdl:create-texture-from-surface
   *renderer* 
   (sdl:ttf-render-text-blended (get-font) text '(#xee #xee #xee #xff))))
(export 'create-texture-from-text)
