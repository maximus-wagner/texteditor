(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :state)
    (defpackage :state
      (:use :cl)
      ;; (:local-nicknames (:metrics :lists.metrics))
      )))
(in-package :state)

(defparameter *renderer* nil)
(export '*renderer*)

(defparameter *font-size-px* 16.0)
(defparameter *font* nil)
(defun get-font ()
  (when (not *font*)
    (setf *font* (sdl:ttf-open-font
                  (namestring
                   (merge-pathnames #p".local/share/fonts/FiraCode-VF.ttf"
                                    (user-homedir-pathname)))
                  *font-size-px*)))
  *font*)
(export 'get-font)
