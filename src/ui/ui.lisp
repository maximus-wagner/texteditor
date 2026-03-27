;;;; ui/ui.lisp -- Modular UI rendering components


(defpackage :ui
  (:use :cl :state :utils :command-frame)
  (:import-from :main
    render-menu-bar render-status-bar render-document render-cursor
    render-file-browser render-help render-notifications))

(in-package :ui)

;; Forward declarations for UI components

(defun render-menu-bar () (render-menu-bar))
(defun render-status-bar () (render-status-bar))
(defun render-document () (render-document))
(defun render-cursor () (render-cursor))
(defun render-file-browser () (render-file-browser))
(defun render-help () (render-help))
(defun render-notifications () (render-notifications))
(defun render-command-frame () (when (command-frame:show-p) (command-frame:render)))

(defun render-ui ()
  (render-document)
  (render-cursor)
  (render-menu-bar)
  (render-status-bar)
  (render-file-browser)
  (render-help)
  (render-notifications)
  (render-command-frame))

(export '(render-ui render-menu-bar render-status-bar render-document render-cursor render-file-browser render-help render-notifications render-command-frame))
