(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :state)
    (defpackage :state
      (:use :cl)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :state)

(defparameter *renderer* nil)
(export '*renderer*)
