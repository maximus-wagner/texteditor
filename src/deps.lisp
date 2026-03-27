;;;; deps.lisp -- Dependencies and library loading
;;;;
;;;; Loads Quicklisp, CFFI, and configures foreign library search paths.
;;;; This file should be loaded before any CFFI bindings.

;; Load Quicklisp setup
(load (merge-pathnames #p"quicklisp/setup.lisp" (user-homedir-pathname)))
(ql:quickload '(:cffi))

;; Add MinGW64 to the search path for Windows
(pushnew (merge-pathnames #p"mingw64/opt/bin/" (user-homedir-pathname)) cffi:*foreign-library-directories*)

;; Load CFFI-libffi for foreign function calls
(ql:quickload '(:cffi-libffi))