(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :utils)
    (defpackage :utils
      (:use :cl)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :utils)

(defun fmteo (&rest args)
  (apply #'format *error-output* args))
(export 'fmteo)
