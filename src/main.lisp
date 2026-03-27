(load (merge-pathnames #p"quicklisp/setup.lisp" (user-homedir-pathname)))
(ql:quickload '(:cffi :cffi-libffi))

(load "src/sdl.lisp")
(load "src/state.lisp")
(load "src/cursor.lisp")
(load "src/utils.lisp")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :main)
    (defpackage :main
      (:use :cl :state :utils)
      (:export #:set-running #:*running* #:*show-fps* #:*current-file*
               #:set-message #:open-file #:save-file #:open-file-browser
               #:bind-key #:show-help #:*keybindings* #:*action-names*
               #:*notifications-enabled* #:push-notification #:main
               #:render-state #:*cwd*))))

(load "src/command-frame.lisp")

(in-package :main)
(require 'uiop)

;;; ================================================================
;;;  Constants
;;; ================================================================

(defparameter +char-width+ 8)
(defparameter +char-height+ 16)
(defparameter +menu-height+ 18)
(defparameter +tab-height+  18)
(defparameter +doc-top+     (+ +menu-height+ +tab-height+))  ; 36
(defparameter +status-bar-h+ 18)
(defparameter +border-height+ 16)
(defparameter +cursor-period-ms+ 500)
(defparameter +message-timeout-ms+ 3500)
(defparameter +notification-timeout-ms+ 4000)
(defparameter +notification-max+ 5)
(defparameter +undo-max+ 200)

;;; ================================================================
;;;  State variables
;;; ================================================================

(defvar *running* t)
(defvar *document* "")
(defvar *cursor-pos* 0)
(defvar *current-file* nil)
(defvar *mode* :insert)
(defvar *clipboard* "")
(defvar *scroll-y* 0)
(defvar *window-width* 640)
(defvar *window-height* 480)
(defvar *show-fps* nil)
(defvar *sel-anchor* 0)
(defvar *shift-sel-active* nil)
(defvar *shift-sel-anchor* 0)
(defvar *undo-stack* nil)
(defvar *redo-stack* nil)
(defvar *message* "")
(defvar *message-start* 0)
(defvar *notifications-enabled* t)
(defvar *notifications* nil)
(defvar *help-active* nil)
(defvar *fb-active* nil)
(defvar *fb-dir* "")
(defvar *fb-entries* '())
(defvar *fb-cursor* 0)
(defvar *fb-scroll* 0)
(defvar *fb-search* "")
(defvar *mouse-dragging* nil)
(defvar *menu-open* nil)
(defvar *menu-hover* nil)
(defvar *menu-keyboard-active* nil)
(defvar *window-focused* t)
(defvar *help-scroll* 0)
;;; File browser rename
(defvar *fb-renaming*    nil)
(defvar *fb-rename-text* "")
(defvar *fb-undo-stack*  nil)
(defvar *fb-redo-stack*  nil)

;;; Search bar
(defvar *search-active*       nil)
(defvar *search-text*         "")
(defvar *search-replace-text* "")
(defvar *search-match-case*   nil)
(defvar *search-whole-word*   nil)
(defvar *search-matches*      nil)
(defvar *search-current*      -1)
(defvar *search-focus*        :find)
(defvar +cursor-start+ 0)
(defvar *window*             nil)   ; SDL window pointer for fullscreen toggle
(defvar *fullscreen*         nil)   ; current fullscreen state
(defvar *window-resize-time* 0)     ; ticks when last resize happened
(defvar *prev-win-w*         0)
(defvar *prev-win-h*         0)

;;; Color theme
(defvar *color-theme* :dark)  ; :dark or :light

;;; Plugin support
(defvar *plugins-dir* (namestring (merge-pathnames #p"plugins/" (user-homedir-pathname))))

;;; Settings overlay
(defvar *settings-active*    nil)
(defvar *settings-section*   0)      ; 0=Appearance 1=Autosave 2=Font 3=Display
(defvar *settings-row*       0)
(defvar *settings-scroll*    0)
(defvar *settings-editing*   nil)     ; nil/:text/:number
(defvar *settings-edit-buf*  "")
(defvar *settings-edit-field* nil)

;;; Tab system
(defstruct tab-state
  (document   "" :type string)
  (cursor-pos  0 :type fixnum)
  (scroll-y    0 :type fixnum)
  (current-file nil)
  (mode       :insert)
  (undo-stack  nil)
  (redo-stack  nil)
  (doc-dirty   nil))

(defvar *tabs*        nil)   ; list of tab-state structs
(defvar *current-tab* 0)     ; index of active tab
(defvar *last-tab*    -1)    ; index of previous tab (for Ctrl+` toggle)
(defvar *closed-tabs* nil)   ; stack of recently closed tab-states (for restore)
(defvar *tab-close-hover* -1)
(defvar *fps* nil)
(defvar *last-fps* nil)
(defvar *keybindings* (make-hash-table :test 'equal))

;;; Autosave / persistence
(defvar *doc-dirty* nil)
(defvar *last-saved-time* nil)
(defvar *autosave-enabled* t)
(defvar *settings-file* (namestring (merge-pathnames #p".texteditor-settings" (user-homedir-pathname))))

;;; Working directory (shell-like cwd for /cd, /ls, /pwd commands)
(defvar *cwd* (namestring (truename (user-homedir-pathname))))

;;; ================================================================
;;;  Exports
;;; ================================================================

(export '(*running* *show-fps* *current-file* *notifications-enabled*
          *keybindings* *action-names* *cwd*))

;;; ================================================================
;;;  Basic functions (no dependencies)
;;; ================================================================

(defun set-running (v) (setf *running* v))
(export 'set-running)

(defun set-message (text)
  (setf *message* text *message-start* (sdl:get-ticks)))
(export 'set-message)

(defun reset-blink () (setf +cursor-start+ (sdl:get-ticks)))

(defun doc-length () (length *document*))

(defun char-at (pos)
  (when (and (>= pos 0) (< pos (doc-length))) (char *document* pos)))

;;; ================================================================
;;;  Line navigation
;;; ================================================================

(defun line-start (pos)
  (if (zerop pos) 0
      (loop for i from (1- pos) downto 0
            do (when (char= (char *document* i) #\Newline) (return (1+ i)))
            finally (return 0))))

(defun line-end (pos)
  (loop for i from pos below (doc-length)
        do (when (char= (char *document* i) #\Newline) (return i))
        finally (return (doc-length))))

(defun next-line-start (pos)
  (loop for i from pos below (doc-length)
        do (when (char= (char *document* i) #\Newline) (return (1+ i)))
        finally (return nil)))

(defun col-at (pos) (- pos (line-start pos)))

;;; Cached line-col: only recompute when cursor or document changes
(defvar *lc-cache-pos* -1)
(defvar *lc-cache-len* -1)
(defvar *lc-cache-val* '(0 0))

(defun cursor-line-col (&optional (pos *cursor-pos*))
  (let ((dlen (length *document*)))
    (unless (and (= pos *lc-cache-pos*) (= dlen *lc-cache-len*))
      (let ((line 0) (col 0))
        (loop for i from 0 below (min pos dlen)
              do (if (char= (char *document* i) #\Newline)
                     (setq line (1+ line) col 0)
                     (incf col)))
        (setf *lc-cache-val* (list line col)
              *lc-cache-pos* pos
              *lc-cache-len* dlen)))
    *lc-cache-val*))

(defun move-up (pos)
  (let* ((col (col-at pos))
         (pls (let ((ls (line-start pos))) (when (> ls 0) (line-start (1- ls))))))
    (if pls (min (+ pls col) (line-end pls)) pos)))

(defun move-down (pos)
  (let* ((col (col-at pos)) (nls (next-line-start pos)))
    (if nls (min (+ nls col) (line-end nls)) pos)))

;;; ================================================================
;;;  Word movement
;;; ================================================================

(defun word-char-p (ch)
  (and ch (or (alphanumericp ch) (char= ch #\_))))

(defun word-start-backward (pos)
  (let ((p (1- pos)))
    (loop while (and (> p 0)
                     (let ((c (char-at p)))
                       (and c (not (word-char-p c)) (not (char= c #\Newline)))))
          do (decf p))
    (loop while (and (> p 0) (word-char-p (char-at (1- p)))) do (decf p))
    p))

(defun word-end-forward (pos)
  (let ((p pos) (n (doc-length)))
    (loop while (and (< p n)
                     (let ((c (char-at p)))
                       (and c (not (word-char-p c)) (not (char= c #\Newline)))))
          do (incf p))
    (loop while (and (< p n) (word-char-p (char-at p))) do (incf p))
    p))

;;; ================================================================
;;;  Document mutation
;;; ================================================================

(defun push-undo ()
  (push (cons (copy-seq *document*) *cursor-pos*) *undo-stack*)
  (setf *redo-stack* nil)
  (when (> (length *undo-stack*) +undo-max+)
    (setf *undo-stack* (subseq *undo-stack* 0 +undo-max+))))

(defun insert-text (text &optional (pos *cursor-pos*))
  (push-undo)
  (setf *document*
    (concatenate 'string (subseq *document* 0 pos) text (subseq *document* pos)))
  (incf *cursor-pos* (length text))
  (reset-blink)
  (setf *doc-dirty* t)
  (when (and *autosave-enabled* *current-file*)
    (save-file nil t)))


(defun delete-range (from to)
  (when (> to from)
    (push-undo)
    (setf *document*
          (concatenate 'string (subseq *document* 0 from) (subseq *document* to)))
    (setf *cursor-pos* (max 0 (min *cursor-pos* from)))
    (reset-blink)
    (setf *doc-dirty* t)
    (when (and *autosave-enabled* *current-file*)
      (save-file nil t))))

;;; ================================================================
;;;  Selection
;;; ================================================================

(defun sel-range ()
  (cond
    ((eq *mode* :visual)
     (list (min *sel-anchor* *cursor-pos*) (max *sel-anchor* *cursor-pos*)))
    (*shift-sel-active*
     (list (min *shift-sel-anchor* *cursor-pos*) (max *shift-sel-anchor* *cursor-pos*)))
    (t nil)))

(defun selection-text ()
  (let ((r (sel-range))) (when r (subseq *document* (first r) (second r)))))

(defun clear-selection ()
  (setf *shift-sel-active* nil)
  (when (eq *mode* :visual) (setf *mode* :normal)))

(defun delete-selection ()
  (let ((r (sel-range)))
    (when r (delete-range (first r) (second r)) (clear-selection) t)))

;;; ================================================================
;;;  Undo / Redo
;;; ================================================================

(defun do-undo ()
  (if *undo-stack*
      (let ((old (pop *undo-stack*)))
        (push (cons (copy-seq *document*) *cursor-pos*) *redo-stack*)
        (setf *document* (car old) *cursor-pos* (cdr old))
        (set-message "Undo"))
      (set-message "Nothing to undo")))

(defun do-redo ()
  (if *redo-stack*
      (let ((old (pop *redo-stack*)))
        (push (cons (copy-seq *document*) *cursor-pos*) *undo-stack*)
        (setf *document* (car old) *cursor-pos* (cdr old))
        (set-message "Redo"))
      (set-message "Nothing to redo")))

;;; ================================================================
;;;  Tab management
;;; ================================================================

(defun tab-name (tab)
  (let ((f (tab-state-current-file tab)))
    (if f
        (let ((n (file-namestring f)))
          (if (tab-state-doc-dirty tab) (format nil "~a*" n) n))
        (if (tab-state-doc-dirty tab) "Untitled*" "Untitled"))))

(defun save-current-tab ()
  (when (and *tabs* (< *current-tab* (length *tabs*)))
    (let ((tab (nth *current-tab* *tabs*)))
      (setf (tab-state-document    tab) *document*
            (tab-state-cursor-pos  tab) *cursor-pos*
            (tab-state-scroll-y    tab) *scroll-y*
            (tab-state-current-file tab) *current-file*
            (tab-state-mode        tab) *mode*
            (tab-state-undo-stack  tab) *undo-stack*
            (tab-state-redo-stack  tab) *redo-stack*
            (tab-state-doc-dirty   tab) *doc-dirty*))))

(defun load-tab (idx)
  (when (and (>= idx 0) (< idx (length *tabs*)))
    (setf *current-tab* idx)
    (let ((tab (nth idx *tabs*)))
      (setf *document*     (tab-state-document    tab)
            *cursor-pos*   (tab-state-cursor-pos  tab)
            *scroll-y*     (tab-state-scroll-y    tab)
            *current-file* (tab-state-current-file tab)
            *mode*         (tab-state-mode        tab)
            *undo-stack*   (tab-state-undo-stack  tab)
            *redo-stack*   (tab-state-redo-stack  tab)
            *doc-dirty*    (tab-state-doc-dirty   tab)
            *lc-cache-pos* -1
            *lc-cache-len* -1))))

(defun new-tab ()
  (save-current-tab)
  (let ((tab (make-tab-state :mode :insert)))
    (setf *tabs* (append *tabs* (list tab)))
    (load-tab (1- (length *tabs*)))))

(defun close-tab ()
  (when (>= (length *tabs*) 1)
    (save-current-tab)
    (push (nth *current-tab* *tabs*) *closed-tabs*)
    (setf *tabs* (append (subseq *tabs* 0 *current-tab*)
                         (subseq *tabs* (1+ *current-tab*))))
    (when (null *tabs*)
      (setf *tabs* (list (make-tab-state :mode :insert))))
    (load-tab (max 0 (min *current-tab* (1- (length *tabs*)))))))

(defun restore-tab ()
  (when *closed-tabs*
    (save-current-tab)
    (let ((tab (pop *closed-tabs*)))
      (setf *tabs* (append *tabs* (list tab)))
      (load-tab (1- (length *tabs*))))))

(defun switch-tab (idx)
  (when (and (>= idx 0) (< idx (length *tabs*)) (/= idx *current-tab*))
    (setf *last-tab* *current-tab*)
    (save-current-tab)
    (load-tab idx)))

;;; ================================================================
;;;  Scroll
;;; ================================================================

(defun scroll-to-cursor ()
  (let* ((lc (cursor-line-col))
         (line (first lc))
         (py (+ +doc-top+ (* line +char-height+)))
         (pad +char-height+)
         (usable-h (- *window-height* +border-height+ +status-bar-h+ +menu-height+)))
    (when (< py (+ *scroll-y* pad))
      (setf *scroll-y* (max 0 (- py pad))))
    (when (> (+ py +char-height+) (+ *scroll-y* usable-h (- pad)))
      (setf *scroll-y* (max 0 (- (+ py +char-height+ pad) usable-h))))))

;;; ================================================================
;;;  File I/O
;;; ================================================================

(defun open-file (path)
  (let ((resolved (probe-file path)))
    (if resolved
        (handler-case
            (progn
              (setf *document* (uiop:read-file-string resolved)
                    *cursor-pos* 0 *scroll-y* 0
                    *current-file* (namestring resolved)
                    *undo-stack* nil *redo-stack* nil
                    *doc-dirty* nil
                    *last-saved-time* (get-universal-time))
              (set-message (format nil "Opened: ~a" *current-file*)))
          (error (e)
            (declare (ignore e))
            (set-message (format nil "Cannot open (binary/locked?): ~a"
                                 (file-namestring (namestring path))))))
        (set-message (format nil "File not found: ~a" path)))))
(export 'open-file)

(defun save-file (&optional path (silent nil))
  (let ((dest (or path *current-file*)))
    (if dest
        (progn
          (with-open-file (f dest :direction :output :if-exists :supersede
                                  :if-does-not-exist :create)
            (write-string *document* f))
          (setf *current-file* dest)
          (setf *doc-dirty* nil)
          (setf *last-saved-time* (get-universal-time))
          (unless silent (set-message (format nil "Saved: ~a" dest))))
        (unless silent (set-message "No file path. Use /w <path>")))))
(export 'save-file)

;;; ================================================================
;;;  File browser
;;; ================================================================

(defun file-size-str (bytes)
  (cond
    ((null bytes)              "")
    ((< bytes 1024)            (format nil "~dB" bytes))
    ((< bytes (* 1024 1024))   (format nil "~dK" (floor bytes 1024)))
    (t                         (format nil "~dM" (floor bytes (* 1024 1024))))))

(defun file-date-str (utime)
  (when utime
    (multiple-value-bind (s mn h day month year)
        (decode-universal-time utime)
      (declare (ignore s))
      (format nil "~2,'0d/~2,'0d ~2,'0d:~2,'0d" day month h mn))))

(defun fb-list-dir (dir)
  (let ((entries (list (list ".." :dir nil nil))))
    (dolist (p (ignore-errors (uiop:subdirectories dir)))
      (let ((name (car (last (pathname-directory p)))))
        (when (and name (not (string= name ".")) (not (string= name "..")))
          (push (list name :dir nil (ignore-errors (file-write-date p))) entries))))
    (dolist (p (ignore-errors (uiop:directory-files dir)))
      (let* ((name (file-namestring p))
             (size (ignore-errors (with-open-file (f p) (file-length f))))
             (date (ignore-errors (file-write-date p))))
        (push (list name :file size date) entries)))
    (let ((dirs  (remove-if-not (lambda (e) (eq (second e) :dir))  entries))
          (files (remove-if-not (lambda (e) (eq (second e) :file)) entries)))
      (append (sort dirs  #'string< :key #'first)
              (sort files #'string< :key #'first)))))

(defun fb-filtered-entries ()
  (if (and *fb-search* (> (length *fb-search*) 0))
      (remove-if-not (lambda (e)
                       (search (string-downcase *fb-search*)
                               (string-downcase (first e))))
                     *fb-entries*)
      *fb-entries*))
;;; Fallback helpers for directory copy/delete when UIOP helpers are unavailable
(defun copy-directory-tree-fallback (from to)
  "Cross-platform fallback to copy a directory tree using system tools.
   FROM/TO may be pathnames or strings. Returns true on success, nil on failure."
  (let* ((froms (if (pathnamep from) (namestring from) (prin1-to-string from)))
         (tos   (if (pathnamep to)   (namestring to)   (prin1-to-string to))))
    (handler-case
        (progn
          (if (member :windows *features*)
              (progn
                (sb-ext:run-program "robocopy" (list froms tos "/e") :wait t)
                t)
              (progn
                (sb-ext:run-program "cp" (list "-r" froms tos) :wait t)
                t)))
      (error (e)
        (format t "copy-directory-tree-fallback failed: ~S~%" e)
        nil))))

(defun delete-directory-tree-fallback (path &key (validate nil))
  "Fallback to delete a directory tree using system tools. Returns t on success."
  (let ((pstr (if (pathnamep path) (namestring path) (prin1-to-string path))))
    (handler-case
        (progn
          (if (member :windows *features*)
              (progn (sb-ext:run-program "cmd" (list "/c" "rmdir" "/s" "/q" pstr) :wait t))
              (progn (sb-ext:run-program "rm" (list "-rf" pstr) :wait t)))
          t)
      (error (e)
        (format t "delete-directory-tree-fallback failed: ~S~%" e)
        nil))))

(defun call-copy-directory-tree (from to)
  "Call UIOP's copy-directory-tree if available, otherwise use fallback." 
  (let ((pkg (find-package :uiop)) (pkg2 (ignore-errors (find-package "UIOP/DRIVER"))))
    (or (and pkg (multiple-value-bind (sym status) (find-symbol "COPY-DIRECTORY-TREE" pkg)
               (and sym (fboundp sym) (funcall sym from to))))
        (and pkg2 (multiple-value-bind (sym status) (find-symbol "COPY-DIRECTORY-TREE" pkg2)
                (and sym (fboundp sym) (funcall sym from to))))
        (copy-directory-tree-fallback from to))))

(defun call-delete-directory-tree (path &key (validate nil))
  "Call UIOP's delete-directory-tree if available, otherwise use fallback." 
  (let ((pkg (find-package :uiop)) (pkg2 (ignore-errors (find-package "UIOP/DRIVER"))))
    (or (and pkg (multiple-value-bind (sym status) (find-symbol "DELETE-DIRECTORY-TREE" pkg)
               (and sym (fboundp sym) (funcall sym path :validate validate))))
        (and pkg2 (multiple-value-bind (sym status) (find-symbol "DELETE-DIRECTORY-TREE" pkg2)
                (and sym (fboundp sym) (funcall sym path :validate validate))))
        (delete-directory-tree-fallback path :validate validate))))

(defun fb-confirm-rename ()
  (when (and *fb-renaming* (> (length *fb-rename-text*) 0))
    (let* ((filtered (fb-filtered-entries))
           (entry    (when (< *fb-cursor* (length filtered)) (nth *fb-cursor* filtered)))
           (old-name (when entry (first entry))))
      (when old-name
        (let* ((old-path (merge-pathnames old-name (pathname *fb-dir*)))
               (new-path (merge-pathnames *fb-rename-text* (pathname *fb-dir*))))
          (handler-case
              (progn (rename-file old-path new-path)
                     (setf *fb-entries* (fb-list-dir *fb-dir*)))
            (error (e) (set-message (format nil "Rename failed: ~a" e))))))))
  (setf *fb-renaming* nil *fb-rename-text* ""))

(defun open-file-browser (&optional dir)
  (let ((d (or dir *cwd* (namestring (truename (user-homedir-pathname))))))
    (setf *fb-active* t *fb-dir* d *cwd* d
          *fb-entries* (fb-list-dir d) *fb-cursor* 0 *fb-scroll* 0
          *fb-undo-stack* nil *fb-redo-stack* nil)))
(export 'open-file-browser)

(defun fb-delete-selected ()
  (let* ((filtered (fb-filtered-entries))
         (entry (when (< *fb-cursor* (length filtered)) (nth *fb-cursor* filtered))))
    (when (and entry (not (string= (first entry) "..")))
      (let* ((name (first entry))
             (path (merge-pathnames name (pathname *fb-dir*)))
             (is-dir (eq (second entry) :dir))
             (tmp (merge-pathnames (format nil ".~a.bak" name)
                                   (pathname *fb-dir*))))
        (handler-case
            (progn
              (if is-dir
                  (progn
                    (call-copy-directory-tree path tmp)
                    (call-delete-directory-tree path :validate t))
                  (rename-file path tmp))
              (push (cons name is-dir) *fb-undo-stack*)
              (setf *fb-redo-stack* nil
                    *fb-entries* (fb-list-dir *fb-dir*)
                    *fb-cursor* (max 0 (min *fb-cursor* (1- (length (fb-filtered-entries))))))
              (push-notification (format nil "Deleted: ~a" name)))
          (error (e) (push-notification (format nil "Delete failed: ~a" e))))))))

(defun fb-undo-delete ()
  (when *fb-undo-stack*
    (let* ((item (pop *fb-undo-stack*))
           (name (car item))
           (is-dir (cdr item))
           (tmp (merge-pathnames (format nil ".~a.bak" name)
                                 (pathname *fb-dir*)))
           (orig (merge-pathnames name (pathname *fb-dir*))))
      (handler-case
          (progn
            (if is-dir
                (progn
                  (call-copy-directory-tree tmp orig)
                  (call-delete-directory-tree tmp :validate t))
                (rename-file tmp orig))
            (push item *fb-redo-stack*)
            (setf *fb-entries* (fb-list-dir *fb-dir*))
            (push-notification (format nil "Restored: ~a" name)))
        (error (e) (push-notification (format nil "Restore failed: ~a" e)))))))

(defun fb-redo-delete ()
  (when *fb-redo-stack*
    (let* ((item (pop *fb-redo-stack*))
           (name (car item))
           (orig (merge-pathnames name (pathname *fb-dir*))))
      (handler-case
          (progn
            (if (cdr item)
                (progn
                  (uiop:delete-directory-tree orig :validate t))
                (delete-file orig))
            (push item *fb-undo-stack*)
            (setf *fb-entries* (fb-list-dir *fb-dir*))
            (push-notification (format nil "Redeleted: ~a" name)))
        (error (e) (push-notification (format nil "Redelete failed: ~a" e)))))))

(defun handle-file-browser-key (scancode key ctrl)
  (let* ((filtered (fb-filtered-entries))
         (n        (length filtered)))
    (cond
      ;; Rename-mode backspace
      ((and *fb-renaming* (= key (char-code #\Backspace)))
       (when (> (length *fb-rename-text*) 0)
         (setf *fb-rename-text* (subseq *fb-rename-text* 0 (1- (length *fb-rename-text*))))))
      ;; Search backspace (only when not renaming)
      ((and (not *fb-renaming*) (= key (char-code #\Backspace)))
       (when (> (length *fb-search*) 0)
         (setf *fb-search* (subseq *fb-search* 0 (1- (length *fb-search*)))
               *fb-cursor* 0 *fb-scroll* 0)))
      ;; Move up
      ((or (= scancode 82) (= scancode 96))
       (when (> *fb-cursor* 0) (decf *fb-cursor*))
       (when (< *fb-cursor* *fb-scroll*) (setf *fb-scroll* *fb-cursor*)))
      ;; Move down
      ((or (= scancode 81) (= scancode 90))
       (when (< *fb-cursor* (1- n)) (incf *fb-cursor*)))
      ;; Page up
      ((or (= scancode 75) (= scancode 97))
       (setf *fb-cursor* (max 0 (- *fb-cursor* 8))))
      ;; Page down
      ((or (= scancode 78) (= scancode 91))
       (setf *fb-cursor* (min (max 0 (1- n)) (+ *fb-cursor* 8))))
      ;; Home
      ((or (= scancode 74) (= scancode 95))
       (setf *fb-cursor* 0 *fb-scroll* 0))
      ;; End
      ((or (= scancode 77) (= scancode 89))
       (setf *fb-cursor* (max 0 (1- n))))
      ;; Open / enter directory
      ((or (= key (char-code #\Return)) (= scancode 79))
       (when (< *fb-cursor* n)
         (let* ((entry (nth *fb-cursor* filtered))
                (name  (first entry))
                (type  (second entry)))
           (if (eq type :dir)
               (let ((new-dir (if (string= name "..")
                                  (uiop:pathname-parent-directory-pathname (pathname *fb-dir*))
                                  (merge-pathnames (make-pathname :directory (list :relative name))
                                                   (pathname *fb-dir*)))))
                 (setf *fb-dir*     (namestring (truename new-dir))
                       *cwd*        *fb-dir*
                       *fb-entries* (fb-list-dir *fb-dir*)
                       *fb-search*  ""
                       *fb-cursor*  0 *fb-scroll* 0))
               (progn
                 (open-file (namestring (merge-pathnames name (pathname *fb-dir*))))
                 (setf *fb-active* nil *fb-search* ""))))))
      ;; Parent directory
      ((= scancode 80)
       (let ((parent (uiop:pathname-parent-directory-pathname (pathname *fb-dir*))))
         (setf *fb-dir*     (namestring (truename parent))
               *cwd*        *fb-dir*
               *fb-entries* (fb-list-dir *fb-dir*)
               *fb-search*  ""
               *fb-cursor*  0 *fb-scroll* 0)))
      ;; Rename mode: Enter confirms, Esc cancels
      ((and *fb-renaming* (= key (char-code #\Return)))
       (fb-confirm-rename))
      ((and *fb-renaming* (= key (char-code #\Esc)))
       (setf *fb-renaming* nil *fb-rename-text* ""))
      ;; Delete selected file/directory (scancode 76 = Delete key)
      ((and (not *fb-renaming*) (= scancode 76))
       (fb-delete-selected))
      ;; Ctrl+R = rename selected file
      ((and ctrl (= key (char-code #\r)))
       (let* ((f (fb-filtered-entries))
              (entry (when (< *fb-cursor* (length f)) (nth *fb-cursor* f))))
         (when (and entry (not (string= (first entry) "..")))
           (setf *fb-renaming* t *fb-rename-text* (first entry)))))
      ;; Ctrl+Z = undo delete
      ((and ctrl (= key (char-code #\z)))
       (fb-undo-delete))
      ;; Ctrl+Y / Ctrl+Shift+Z = redo delete
      ((and ctrl (or (= key (char-code #\y))
                     (= key (char-code #\Z))))
       (fb-redo-delete))
      ;; Ctrl+N = new file in current directory (via command frame)
      ((and ctrl (= key (char-code #\n)))
       (setf *fb-active* nil *fb-search* "")
       (command-frame:show (format nil "/touch ")))
      ;; Ctrl+M = new directory in current directory
      ((and ctrl (= key (char-code #\m)))
       (setf *fb-active* nil *fb-search* "")
       (command-frame:show (format nil "/mkdir ")))
      ;; Ctrl+G = go to path (jump directory via command frame)
      ((and ctrl (= key (char-code #\g)))
       (setf *fb-active* nil *fb-search* "")
       (command-frame:show (format nil "/cd ")))
      ;; Close
      ((or (= key (char-code #\Esc)) (= key (char-code #\q)))
       (cond
         (*fb-renaming* (setf *fb-renaming* nil *fb-rename-text* ""))
         ((> (length *fb-search*) 0) (setf *fb-search* "" *fb-cursor* 0 *fb-scroll* 0))
         (t (setf *fb-active* nil *fb-search* "")))))))

;;; ================================================================
;;;  Help overlay
;;; ================================================================

(defun show-help () (setf *help-active* t *help-scroll* 0))
(export 'show-help)

;;; ================================================================
;;;  Keybinding system
;;; ================================================================

(defun bind-key (mode keyname action)
  (setf (gethash (format nil "~a:~a" (symbol-name mode) (string-downcase keyname))
                 *keybindings*) action))
(export 'bind-key)

(defun lookup-binding (mode keyname)
  (gethash (format nil "~a:~a" (symbol-name mode) (string-downcase keyname)) *keybindings*))

;;; Initialize default keybindings (do not overwrite existing user bindings)
(defun init-default-keybindings ()
  "Populate `*keybindings*` with sensible defaults for normal, insert, and visual modes.
This checks for existing bindings and leaves them intact so user customisations persist." 
  (labels ((safe-bind (mode key action)
             (unless (lookup-binding mode key)
               (bind-key mode key action))))
    ;; Normal mode (vim-like)
    (safe-bind :normal "h" :move-left)
    (safe-bind :normal "l" :move-right)
    (safe-bind :normal "j" :move-down)
    (safe-bind :normal "k" :move-up)
    (safe-bind :normal "0" :move-line-start)
    (safe-bind :normal "$" :move-line-end)
    (safe-bind :normal "w" :move-word-forward)
    (safe-bind :normal "b" :move-word-backward)
    (safe-bind :normal "i" :insert-mode)
    (safe-bind :normal "a" :insert-after)
    (safe-bind :normal "o" :open-line-below)
    (safe-bind :normal "x" :delete-char)
    (safe-bind :normal "p" :paste)
    (safe-bind :normal "y" :yank-line)
    (safe-bind :normal "v" :visual-mode)
    (safe-bind :normal ":" :open-command)
    (safe-bind :normal "u" :undo)
    (safe-bind :normal "ctrl+r" :redo)

    ;; Insert mode
    (safe-bind :insert "esc" :normal-mode)
    (safe-bind :insert "ctrl+s" :save-file)
    (safe-bind :insert "ctrl+o" :open-file-browser)
    (safe-bind :insert "ctrl+z" :undo)
    (safe-bind :insert "ctrl+y" :redo)
    (safe-bind :insert "ctrl+c" :copy)
    (safe-bind :insert "ctrl+x" :cut)
    (safe-bind :insert "ctrl+v" :paste)
    (safe-bind :insert "ctrl+a" :select-all)
    (safe-bind :insert "ctrl+f" :find)

    ;; Visual mode (movement + copy/cut/paste)
    (safe-bind :visual "h" :move-left)
    (safe-bind :visual "l" :move-right)
    (safe-bind :visual "j" :move-down)
    (safe-bind :visual "k" :move-up)
    (safe-bind :visual "y" :copy)
    (safe-bind :visual "d" :cut)
    (safe-bind :visual "x" :cut)
    (safe-bind :visual "p" :paste)
    (safe-bind :visual "esc" :normal-mode)))

;; Custom keybindings disabled — key dispatch uses hardcoded cond blocks below
;; (init-default-keybindings)

;;; Settings persistence
(defun load-window-size ()
  "Read window dimensions from settings. If was fullscreen, return default size
   so window creates at normal size before SDL switches to fullscreen."
  (ignore-errors
    (when (probe-file *settings-file*)
      (with-open-file (s *settings-file* :direction :input)
        (let ((data (read s nil nil)))
          (when (listp data)
            (let ((w  (getf data :window-w))
                  (h  (getf data :window-h))
                  (fs (getf data :fullscreen)))
              ;; If was fullscreen, start at default windowed size
              (if fs
                  '(800 600)
                  (when (and w h (> w 100) (> h 100)) (list w h))))))))))

(defun save-settings ()
  (when *settings-file*
    (handler-case
        (progn
          (save-current-tab)
          (with-open-file (s *settings-file* :direction :output
                                             :if-exists :supersede
                                             :if-does-not-exist :create)
             (write (list :autosave *autosave-enabled*
                          :show-fps *show-fps*
                          :window-w *window-width*
                          :window-h *window-height*
                          :fullscreen *fullscreen*
                          :color-theme *color-theme*
                          :notifications *notifications-enabled*
                          :session-files (mapcar #'tab-state-current-file *tabs*)
                          :session-current *current-tab*)
                   :stream s)))
      (error (e) (format t "Failed to save settings: ~a~%" e)))))

(defun load-settings ()
  (when (and *settings-file* (probe-file *settings-file*))
    (handler-case
        (with-open-file (s *settings-file* :direction :input)
          (let ((data (read s nil nil)))
            (when (listp data)
              (let ((autos (getf data :autosave))
                    (fps   (getf data :show-fps))
                    (fs    (getf data :fullscreen))
                    (theme (getf data :color-theme))
                    (notif (getf data :notifications))
                    (files (getf data :session-files))
                    (cur   (or (getf data :session-current) 0)))
                (when (not (null autos)) (setf *autosave-enabled* autos))
                (when (not (null fps))   (setf *show-fps* fps))
                (when theme (setf *color-theme* theme))
                (when (not (null notif)) (setf *notifications-enabled* notif))
                (when fs
                  (setf *fullscreen* t)
                  (when *window* (sdl:set-window-fullscreen *window* t)))
                ;; Restore session
                (when (and files (consp files))
                  (setf *tabs* nil)
                  (dolist (f files)
                    (let ((tab (make-tab-state :mode :insert)))
                      (setf *tabs* (append *tabs* (list tab)))))
                  (when (null *tabs*)
                    (setf *tabs* (list (make-tab-state :mode :insert))))
                  (load-tab 0)
                  (loop for f in files for i from 0
                        do (when (and f (probe-file f))
                             (save-current-tab)
                             (setf *current-tab* i)
                             (load-tab i)
                             (open-file f)))
                  (load-tab (min cur (max 0 (1- (length *tabs*))))))))))
      (error (e) (format t "Failed to load settings: ~a~%" e)))))

;;; ================================================================
;;;  Notifications
;;; ================================================================

(defun push-notification (text)
  (when *notifications-enabled*
    (push (cons text (sdl:get-ticks)) *notifications*)
    (when (> (length *notifications*) +notification-max+)
      (setf *notifications* (subseq *notifications* 0 +notification-max+)))))
(export 'push-notification)

(defun live-notifications ()
  (let ((now (sdl:get-ticks)))
    (reverse (remove-if (lambda (n) (>= (- now (cdr n)) +notification-timeout-ms+))
                        *notifications*))))

;;; ================================================================
;;;  Menu bar data
;;; ================================================================

(defparameter *menus*
  '(("File" (:item "New" :new-file) (:item "Open..." :open-file-browser)
     (:item "Save" :save-file) (:sep) (:item "Exit" :quit))
    ("Edit" (:item "Copy" :copy) (:item "Paste" :paste) (:item "Cut" :cut)
     (:item "Select All" :select-all) (:sep) (:item "Undo" :undo) (:item "Redo" :redo))
    ("View" (:toggle "FPS" :toggle-fps *show-fps*))
    ("Tools" (:toggle "Autosave" :toggle-autosave *autosave-enabled*)
     (:item "Save Now" :save-file) (:item "Settings..." :open-settings))
    ("Help" (:item "Commands" :show-help))
    ("Quit" (:item "Quit" :quit))))

;;; ================================================================
;;;  Actions
;;; ================================================================

;;; Welcome screen
(defparameter *welcome-art*
  '("____   ____.__   _____     "
    "\\   \\ /   /|__| /     \\    "
    " \\   Y   / |  |/  \\ /  \\   "
    "  \\     /  |  /    Y    \\  "
    "   \\___/   |__\\____|__  /  "
    "                      \\/   "
    "    ________               "
    "    \\______ \\ _____ ___  __"
    "     |    |  \\\\__  \\\\  \\/ /"
    "     |    `   \\/ __ \\\\   / "
    "    /_______  (____  /\\_/  "
    "            \\/     \\/      "
    ""
     "     [ ViMDav Text Editor ]"
     ""
     "  i=type  Ctrl+T=new tab  Ctrl+O=open"
    "  Ctrl+F=find  F1-F5=menus  F11=full"))

(defparameter *action-names*
  '(:move-left :move-right :move-up :move-down :move-line-start :move-line-end
    :move-word-forward :move-word-backward :page-up :page-down
    :insert-mode :normal-mode :visual-mode :insert-after :insert-line-end :insert-line-start
    :open-line-below :open-line-above :delete-char :delete-word-back :delete-word-forward
    :yank-line :paste :cut :delete-selection :copy :select-all :undo :redo
    :new-file :save-file :open-command :open-file-browser :show-help :toggle-autosave :toggle-fps
    :open-settings :quit))
(export '*action-names*)

(defun execute-action (action)
  (case action
    (:move-left (when (> *cursor-pos* 0) (decf *cursor-pos*)) (scroll-to-cursor))
    (:move-right (when (< *cursor-pos* (doc-length)) (incf *cursor-pos*)) (scroll-to-cursor))
    (:move-up (setf *cursor-pos* (move-up *cursor-pos*)) (scroll-to-cursor))
    (:move-down (setf *cursor-pos* (move-down *cursor-pos*)) (scroll-to-cursor))
    (:move-line-start (setf *cursor-pos* (line-start *cursor-pos*)) (scroll-to-cursor))
    (:move-line-end (setf *cursor-pos* (line-end *cursor-pos*)) (scroll-to-cursor))
    (:move-word-forward (setf *cursor-pos* (word-end-forward *cursor-pos*)) (scroll-to-cursor))
    (:move-word-backward (setf *cursor-pos* (word-start-backward (min (1+ *cursor-pos*) (doc-length)))) (scroll-to-cursor))
    (:page-up (dotimes (_ 10) (setf *cursor-pos* (move-up *cursor-pos*))) (scroll-to-cursor))
    (:page-down (dotimes (_ 10) (setf *cursor-pos* (move-down *cursor-pos*))) (scroll-to-cursor))
    (:insert-mode (setf *mode* :insert) (reset-blink) (push-notification "INSERT mode"))
    (:normal-mode (setf *mode* :normal) (clear-selection) (reset-blink) (push-notification "NORMAL mode"))
    (:visual-mode (setf *mode* :visual *sel-anchor* *cursor-pos*) (reset-blink) (push-notification "VISUAL mode"))
    (:copy (let ((sel (selection-text))) (when sel (setf *clipboard* sel) (push-notification "Copied"))))
    (:cut (let ((sel (selection-text))) (when sel (setf *clipboard* sel) (push-undo) (delete-selection) (push-notification "Cut"))))
    (:paste (when (> (length *clipboard*) 0) (delete-selection) (insert-text *clipboard*) (push-notification "Pasted")))
    (:select-all (setf *mode* :visual *sel-anchor* 0 *cursor-pos* (doc-length)) (reset-blink) (push-notification "Selected all"))
    (:undo (do-undo) (push-notification "Undo"))
    (:redo (do-redo) (push-notification "Redo"))
    (:delete-selection (delete-selection) (push-notification "Deleted selection"))
    (:new-file (new-tab) (push-notification "New tab"))
    (:save-file (save-file nil) (push-notification "Saved"))
    (:open-command (command-frame:show) (push-notification "Command mode"))
    (:open-file-browser (open-file-browser) (push-notification "File browser"))
    (:show-help (show-help) (push-notification "Commands"))
    (:toggle-fps (setf *show-fps* (not *show-fps*)) (save-settings) (push-notification (if *show-fps* "FPS: ON" "FPS: OFF")))
    (:toggle-autosave (setf *autosave-enabled* (not *autosave-enabled*)) (save-settings) (push-notification (if *autosave-enabled* "Autosave: ON" "Autosave: OFF")))
    (:open-settings (setf *settings-active* t *settings-section* 0 *settings-row* 0 *settings-scroll* 0) (push-notification "Settings"))
    (:quit (push-notification "Quitting") (set-running nil))
    (t nil)))

;;; ================================================================
;;;  Search
;;; ================================================================

(defun find-all-matches (text doc match-case whole-word)
  (when (and text (> (length text) 0))
    (let* ((s  (if match-case doc (string-downcase doc)))
           (t2 (if match-case text (string-downcase text)))
           (tl (length t2))
           (dl (length s))
           matches (pos 0))
      (loop
        (let ((p (search t2 s :start2 pos)))
          (unless p (return))
          (let ((ok (or (not whole-word)
                        (and (or (zerop p) (not (alphanumericp (char s (1- p)))))
                             (or (>= (+ p tl) dl) (not (alphanumericp (char s (+ p tl)))))))))
            (when ok (push (cons p (+ p (length text))) matches)))
          (setf pos (1+ p))))
      (nreverse matches))))

(defun update-search-position ()
  (when (and *search-matches*
             (>= *search-current* 0)
             (< *search-current* (length *search-matches*)))
    (setf *cursor-pos* (car (nth *search-current* *search-matches*)))
    (scroll-to-cursor)))

(defun update-search ()
  (setf *search-matches*
        (if (> (length *search-text*) 0)
            (find-all-matches *search-text* *document* *search-match-case* *search-whole-word*)
            nil))
  (cond
    ((null *search-matches*)  (setf *search-current* -1))
    ((< *search-current* 0)   (setf *search-current* 0) (update-search-position))
    (t (setf *search-current* (min *search-current* (1- (length *search-matches*))))
       (update-search-position))))

(defun search-next ()
  (when *search-matches*
    (setf *search-current* (mod (1+ (max 0 *search-current*)) (length *search-matches*)))
    (update-search-position)))

(defun search-prev ()
  (when *search-matches*
    (setf *search-current* (mod (+ (max 0 *search-current*) -1 (length *search-matches*))
                                (length *search-matches*)))
    (update-search-position)))

(defun search-replace-current ()
  (when (and *search-matches*
             (>= *search-current* 0)
             (< *search-current* (length *search-matches*)))
    (let* ((m  (nth *search-current* *search-matches*))
           (from (car m)) (to (cdr m)))
      (push-undo)
      (setf *document* (concatenate 'string
                          (subseq *document* 0 from)
                          *search-replace-text*
                          (subseq *document* to))
            *cursor-pos* (+ from (length *search-replace-text*))
            *doc-dirty* t
            *lc-cache-pos* -1)
      (update-search))))

(defun search-replace-all ()
  (let ((count 0))
    (when *search-matches*
      (push-undo)
      (loop for (ms . me) in (reverse *search-matches*)
            do (setf *document* (concatenate 'string
                                   (subseq *document* 0 ms)
                                   *search-replace-text*
                                   (subseq *document* me))
                     *doc-dirty* t
                     *lc-cache-pos* -1)
               (incf count))
      (update-search)
      (set-message (format nil "Replaced ~d occurrence~:p" count)))))

;;; ================================================================
;;;  Rendering helpers
;;; ================================================================

(defvar *texture-cache* (make-hash-table :test 'equal))
(defparameter +texture-cache-max+ 2048)   ; evict when over this many entries

(defun cached-render-text-at (text x y &optional (color '(#xee #xee #xee #xff)))
  "Render text at (x,y), caching the texture. Color is part of the cache key."
  (when (and text (> (length text) 0) *renderer*)
    (let* ((key (cons text color))
           (tx (gethash key *texture-cache*)))
      (unless tx
        ;; Keep cache from growing unboundedly on large documents
        (when (>= (hash-table-count *texture-cache*) +texture-cache-max+)
          (clear-texture-cache))
        (setf tx (create-texture-from-text-colored text color))
        (setf (gethash key *texture-cache*) tx))
      (when tx
        (destructuring-bind (w h) (sdl:get-texture-size tx)
          (sdl:render-texture *renderer* tx nil
                              (list x (+ y (- +char-height+ h)) w h)))))))

(defun clear-texture-cache ()
  (maphash (lambda (k v) (declare (ignore k)) (sdl:destroy-texture v)) *texture-cache*)
  (clrhash *texture-cache*))

(defun render-text-at (text x y)
  (when (and text (> (length text) 0) *renderer*)
    (let ((tx (create-texture-from-text text)))
      (destructuring-bind (w h) (sdl:get-texture-size tx)
        (sdl:render-texture *renderer* tx nil
                            (list x (+ y (- +char-height+ h)) w h)))
      (sdl:destroy-texture tx))))

(defun str-trunc (str max-len)
  (if (> (length str) max-len) (subseq str 0 max-len) str))

(defun pixel-to-pos (px py)
  (let* ((doc-y (+ py *scroll-y*))
         (clicked-line (max 0 (floor (- doc-y +doc-top+) +char-height+)))
         (clicked-col (max 0 (floor (- px (+ 4 (line-number-gutter-width))) +char-width+)))
         (lines (uiop:split-string *document* :separator (list #\Newline)))
         (line-idx (min clicked-line (max 0 (1- (length lines)))))
         (col (min clicked-col (length (nth line-idx lines)))))
    (+ col (loop for i from 0 below line-idx sum (1+ (length (nth i lines)))))))

;;; ---- FPS struct ----

(defstruct fps-state (frames 0 :type fixnum) (window-start 0 :type (unsigned-byte 64)) (fps 0.0 :type single-float))
(defun make-fps () (make-fps-state :window-start (sdl:get-ticks)))
(defun fps-tick (s)
  (incf (fps-state-frames s))
  (let* ((now (sdl:get-ticks)) (elapsed (- now (fps-state-window-start s))))
    (when (>= elapsed 1000)
      (setf (fps-state-fps s) (/ (* (fps-state-frames s) 1000.0) elapsed)
            (fps-state-frames s) 0 (fps-state-window-start s) now)
      (fps-state-fps s))))

;;; ---- Menu helpers ----

(defun menu-title-x-positions ()
  (let ((x 4))
    (mapcar (lambda (menu)
              (let* ((name (first menu)) (w (* (+ (length name) 2) +char-width+)))
                (prog1 (list x w) (incf x w))))
            *menus*)))

(defun find-menu-at-x (px)
  (loop for i from 0 for (mx mw) in (menu-title-x-positions)
        when (and (>= px mx) (< px (+ mx mw))) return i))

(defun dropdown-width (menu-idx)
  (let* ((items (rest (nth menu-idx *menus*)))
         (maxlen (loop for item in items
                       when (member (first item) '(:item :toggle))
                       maximize (let ((label (second item)))
                                  (if (eq (first item) :toggle)
                                      (+ (length label) 5)  ; " ON"/" OFF"
                                      (length label)))
                       into m finally (return (or m 8)))))
    (* (+ maxlen 4) +char-width+)))

;;; ================================================================
;;;  Syntax highlighting
;;; ================================================================

;;; Colours
(defparameter +col-default+  '(#xcc #xcc #xcc #xff))
(defparameter +col-comment+  '(#x66 #x77 #x66 #xff))
(defparameter +col-string+   '(#x99 #xdd #x77 #xff))
(defparameter +col-number+   '(#x77 #xcc #xee #xff))
(defparameter +col-keyword+  '(#xff #xcc #x55 #xff))  ; :keyword
(defparameter +col-special+  '(#xff #x88 #x55 #xff))  ; defun/let/when etc.
(defparameter +col-parens+   '(#xaa #xaa #xaa #xff))
(defparameter +col-greyed+        '(#x55 #x55 #x55 #xff))  ; when command frame open
(defparameter +col-search-match+  '(#x33 #x44 #x99 #xff))  ; search result background
(defparameter +col-search-cur+    '(#xbb #x77 #x00 #xff))  ; current search result

(defparameter *special-forms*
  '("defun" "defmacro" "defvar" "defparameter" "defstruct" "defclass"
    "let" "let*" "flet" "labels" "cond" "when" "unless" "if" "and" "or"
    "loop" "do" "dolist" "dotimes" "progn" "lambda" "setf" "setq"
    "case" "ecase" "typecase" "eval-when" "in-package" "defpackage"
    "with-open-file" "handler-case" "handler-bind" "ignore-errors"
    "push" "pop" "incf" "decf" "return-from" "block" "multiple-value-bind"))

(defun lisp-file-p ()
  (and *current-file*
       (let ((name (string-downcase *current-file*)))
         (or (ends-with name ".lisp") (ends-with name ".lsp")
             (ends-with name ".cl")))))

(defun ends-with (str suffix)
  (let ((sl (length str)) (el (length suffix)))
    (and (>= sl el)
         (string= str suffix :start1 (- sl el)))))

(defun tokenize-lisp-line (line)
  "Return list of (start end color) spans for a Lisp source line."
  (let ((n (length line)) (tokens '()) (i 0))
    (loop while (< i n)
          do (let ((ch (char line i)))
               (cond
                 ((char= ch #\;)
                  (push (list i n +col-comment+) tokens)
                  (setf i n))
                 ((char= ch #\")
                  (let ((start i))
                    (incf i)
                    (loop while (< i n)
                          do (let ((c (char line i)))
                               (incf i)
                               (when (char= c #\\) (incf i))
                               (when (char= c #\") (return))))
                    (push (list start i +col-string+) tokens)))
                 ((and (char= ch #\:) (< (1+ i) n)
                       (not (member (char line (1+ i)) '(#\Space #\( #\) #\; #\Newline))))
                  (let ((start i))
                    (incf i)
                    (loop while (and (< i n)
                                     (not (member (char line i) '(#\Space #\( #\) #\; #\, #\" #\Newline))))
                          do (incf i))
                    (push (list start i +col-keyword+) tokens)))
                 ((or (digit-char-p ch)
                      (and (char= ch #\-) (< (1+ i) n) (digit-char-p (char line (1+ i)))))
                  (let ((start i))
                    (when (char= ch #\-) (incf i))
                    (loop while (and (< i n) (digit-char-p (char line i))) do (incf i))
                    (when (and (< i n) (char= (char line i) #\.))
                      (incf i)
                      (loop while (and (< i n) (digit-char-p (char line i))) do (incf i)))
                    (push (list start i +col-number+) tokens)))
                 ((member ch '(#\( #\)))
                  (push (list i (1+ i) +col-parens+) tokens)
                  (incf i))
                 ((not (member ch '(#\Space #\Tab)))
                  (let ((start i))
                    (loop while (and (< i n)
                                     (not (member (char line i) '(#\Space #\( #\) #\; #\Newline))))
                          do (incf i))
                    (let* ((word (subseq line start i))
                           (bare (string-left-trim "'`,#@" word))
                           (color (if (member bare *special-forms* :test #'string=)
                                      +col-special+
                                      +col-default+)))
                      (push (list start i color) tokens))))
                 (t (incf i)))))
    (nreverse tokens)))

(defun render-line-highlighted (line x y)
  "Render a single line with syntax highlighting."
  (when (= (length line) 0) (return-from render-line-highlighted))
  (if (lisp-file-p)
      (let ((tokens (tokenize-lisp-line line)))
        (dolist (tok tokens)
          (destructuring-bind (s e color) tok
            (let ((span (subseq line s e)))
              (when (> (length span) 0)
                (cached-render-text-at span (+ x (* s +char-width+)) y color))))))
      (cached-render-text-at line x y +col-default+)))

;;; ================================================================
;;;  Rendering
;;; ================================================================

;;; ---- Scrollbar ----

(defparameter +col-lnum+    '(#x55 #x66 #x55 #xff))  ; line number colour
(defparameter +col-lnum-cur+ '(#xaa #xbb #xaa #xff)) ; current line number

(defun render-scrollbar (x top-y height total visible first-visible)
  "Render a vertical scrollbar using box characters.
   X, TOP-Y: screen position. HEIGHT: pixel height of scrollbar area.
   TOTAL: total items. VISIBLE: how many fit. FIRST-VISIBLE: scroll offset."
  (when (or (zerop total) (>= visible total)) (return-from render-scrollbar))
  (let* ((rows     (max 2 (floor height +char-height+)))
         (track-h  (- rows 2))            ; rows excluding arrows
         (thumb-h  (max 1 (round (* track-h (/ (float visible) total)))))
         (thumb-y  (if (<= total visible) 0
                       (round (* (- track-h thumb-h)
                                 (/ (float first-visible) (- total visible))))))
         (cy top-y))
    ;; Up arrow
    (cached-render-text-at *sb-up* x cy +col-parens+)
    (incf cy +char-height+)
    ;; Track
    (loop for r from 0 below track-h
          do (let ((ch (if (and (>= r thumb-y) (< r (+ thumb-y thumb-h))) *sb-thumb* *sb-track*)))
               (cached-render-text-at ch x cy +col-parens+)
               (incf cy +char-height+)))
    ;; Down arrow
    (cached-render-text-at *sb-dn* x cy +col-parens+)))

(defun line-number-gutter-width ()
  (let* ((total (1+ (count #\Newline *document*)))
         (digits (max 2 (length (format nil "~d" total)))))
    (* (+ digits 1) +char-width+)))

(defun render-document ()
  (let* ((greyed     (or (command-frame:show-p) *fb-active*))
         (view-top   *scroll-y*)
         (gutter-w   (line-number-gutter-width))
         (doc-x      (+ 4 gutter-w))
         (gutter-x   2)
         (doc        *document*)
         (dlen       (length doc))
         ;; current cursor line for highlighting current line number
         (cur-line   (first (cursor-line-col)))
         (i 0) (line-num 0) (abs-y 0))
    (loop while (<= i dlen)
          do (let* ((nl-pos   (or (position #\Newline doc :start i) dlen))
                    (line     (subseq doc i nl-pos))
                    (screen-y (- (+ +doc-top+ abs-y) view-top)))
               (when (and (> (+ screen-y +char-height+) 0)
                          (< screen-y *window-height*))
                 ;; Line number
                 (let* ((cur (= line-num cur-line))
                        (col (if cur +col-lnum-cur+ +col-lnum+))
                        (ns  (format nil "~3d " (1+ line-num))))
                   (cached-render-text-at ns gutter-x screen-y col))
                 ;; Search match highlights (drawn before text so text appears on top)
                 (when (and *search-active* *search-matches*)
                   (loop for idx from 0 for (ms . me) in *search-matches*
                         when (and (< ms nl-pos) (> me i))
                         do (let* ((col-s (max 0 (- ms i)))
                                   (col-e (min (- nl-pos i) (- me i)))
                                   (sx    (+ doc-x (* col-s +char-width+)))
                                   (sw    (* (- col-e col-s) +char-width+)))
                              (if (= idx *search-current*)
                                  (sdl:set-render-draw-color *renderer* +col-search-cur+)
                                  (sdl:set-render-draw-color *renderer* +col-search-match+))
                              (sdl:render-fill-rect *renderer* (list sx screen-y sw +char-height+)))))
                 ;; Document text
                 (if greyed
                     (cached-render-text-at line doc-x screen-y +col-greyed+)
                     (render-line-highlighted line doc-x screen-y)))
               (when (> screen-y *window-height*) (return))
               (incf abs-y +char-height+)
               (incf line-num)
               (setf i (1+ nl-pos))))))

(defun render-cursor ()
  (when (null *renderer*) (return-from render-cursor))
  (when (command-frame:show-p) (return-from render-cursor))
  (when (not *window-focused*) (return-from render-cursor))
  (when *fb-active* (return-from render-cursor))
  (let* ((lc (cursor-line-col))
         (cursor-y (+ +doc-top+ (* (first lc) +char-height+) (- *scroll-y*)))
         (cursor-x (+ 4 (line-number-gutter-width) (* (second lc) +char-width+))))
    (when (> (- (sdl:get-ticks) +cursor-start+) +cursor-period-ms+)
      (setf +cursor-start+ (sdl:get-ticks)))
    (when (< (- (sdl:get-ticks) +cursor-start+) (/ +cursor-period-ms+ 2))
      (sdl:set-render-draw-color *renderer* '(#xee #xee #xee #xff))
      (sdl:render-fill-rect *renderer* (list cursor-x cursor-y +char-width+ +char-height+)))))

(defun render-status-bar ()
  (when (null *renderer*) (return-from render-status-bar))
  (let* ((bar-y (- *window-height* +status-bar-h+))
         (border-y (- bar-y +border-height+))
         (msg-live (and (> (length *message*) 0)
                        (< (- (sdl:get-ticks) *message-start*) +message-timeout-ms+)))
         (mode-str (if msg-live *message*
                       (case *mode* (:normal "-- NORMAL --") (:insert "-- INSERT --")
                             (:visual "-- VISUAL --") (t "------------"))))
         (lc (cursor-line-col))
         (pos-str (format nil "~a:~a" (1+ (first lc)) (1+ (second lc))))
         (fname (if *current-file*
                    (str-trunc (file-namestring *current-file*) 30)
                    (str-trunc (format nil "~a" *cwd*) 40)))
         (my (+ bar-y (floor (- +status-bar-h+ +char-height+) 2))))
    ;; Draw border row as solid color bar
    (sdl:set-render-draw-color *renderer* '(#x1a #x1a #x1a #xff))
    (sdl:render-fill-rect *renderer* (list 0 border-y *window-width* +border-height+))
    (sdl:set-render-draw-color *renderer* '(#x44 #x44 #x44 #xff))
    (sdl:render-fill-rect *renderer* (list 0 border-y *window-width* 1))
    ;; Status bar background
    (sdl:set-render-draw-color *renderer* '(#x22 #x22 #x22 #xff))
    (sdl:render-fill-rect *renderer* (list 0 bar-y *window-width* +status-bar-h+))
    ;; Mode / message (left)
    (cached-render-text-at mode-str 4 my)
    ;; Filename (centre)
    (cached-render-text-at fname (floor (- *window-width* (* (length fname) +char-width+)) 2) my)
    ;; Position (right)
    (cached-render-text-at pos-str (- *window-width* (* (length pos-str) +char-width+) 4) my)))

(defun render-dim-overlay ()
  "Semi-transparent dark veil behind modal overlays for visual focus."
  (when (and *renderer*
             (or *fb-active* *help-active* *settings-active* (command-frame:show-p)))
    ;; Blend mode 1 is already set globally in main; just draw the overlay
    (sdl:set-render-draw-color *renderer* '(#x00 #x00 #x00 #xa8))
    (sdl:render-fill-rect *renderer* (list 0 0 *window-width* *window-height*))))

(defun render-file-browser ()
  (when (and *fb-active* *renderer*)
    (let* ((filtered  (fb-filtered-entries))
           (n         (length filtered))
           ;; Fixed max width regardless of resolution
           (box-w     (min 900 (max 500 (- *window-width* 40))))
           (box-h     (min (- *window-height* 8) (max 300 (round (* *window-height* 0.85)))))
           (box-x     (floor (- *window-width* box-w) 2))
           (box-y     (floor (- *window-height* box-h) 2))
           (cols      (max 10 (floor box-w +char-width+)))
           (hline     (box-hline (max 0 (- cols 2))))
           (name-cols (max 10 (- cols 38)))  ; fixed side columns: 4+1+4+8+1+15+1 = 34
           (visible   (max 2 (- (floor (- box-h (* 6 +char-height+)) +char-height+) 1)))
           (sb-x      (- (+ box-x box-w) (* 2 +char-width+) 1)))
      ;; Clamp cursor/scroll
      (when (>= *fb-cursor* n) (setf *fb-cursor* (max 0 (1- n))))
      (when (>= *fb-cursor* (+ *fb-scroll* visible))
        (setf *fb-scroll* (max 0 (- *fb-cursor* visible -1))))
      (when (< *fb-cursor* *fb-scroll*)
        (setf *fb-scroll* *fb-cursor*))
      ;; Background
      (sdl:set-render-draw-color *renderer* '(#x10 #x10 #x1c #xff))
      (sdl:render-fill-rect *renderer* (list box-x box-y box-w box-h))
      (let ((y box-y))
        ;; Top border
        (cached-render-text-at
         (concatenate 'string (string *box-tl*) hline (string *box-tr*)) box-x y)
        (incf y +char-height+)
        ;; Directory path row
        (cached-render-text-at
         (box-row (format nil " ~a" *fb-dir*) cols) box-x y)
        (incf y +char-height+)
        ;; Column header
        (let ((header (format nil "  ~3a  ~a ~va ~8a ~15a"
                              "#" " " name-cols "Name" "Size" "Modified")))
          (sdl:set-render-draw-color *renderer* '(#x20 #x20 #x38 #xff))
          (sdl:render-fill-rect *renderer* (list (1+ box-x) y (- box-w 2) +char-height+))
          (cached-render-text-at (box-row header cols) box-x y +col-keyword+))
        (incf y +char-height+)
        ;; Divider
        (cached-render-text-at
         (concatenate 'string (string *box-ml*) hline (string *box-mr*)) box-x y)
        (incf y +char-height+)
        ;; File rows
        (loop for row from 0 below visible
              for idx = (+ *fb-scroll* row)
              while (< idx n)
              do (let* ((entry    (nth idx filtered))
                        (name     (first entry))
                        (is-dir   (eq (second entry) :dir))
                        (fsize    (file-size-str (third entry)))
                        (fdate    (or (file-date-str (fourth entry)) ""))
                        (sel      (= idx *fb-cursor*))
                        (alt      (oddp row))
                        ;; When renaming the selected row, show input text
                        (disp-name (if (and sel *fb-renaming*)
                                       (format nil "~a_" *fb-rename-text*)
                                       (str-pad-right name name-cols)))
                        (prefix   (cond (is-dir "[D]") (*fb-renaming* (if sel "[R]" "   ")) (t "   ")))
                        (bg-col   (cond (sel  '(#x25 #x38 #x5a #xff))
                                        (alt  '(#x18 #x18 #x26 #xff))
                                        (t    '(#x10 #x10 #x1c #xff))))
                        (fg-col   (cond ((and sel *fb-renaming*) '(#xff #xee #x88 #xff))
                                        (sel    '(#xff #xff #xff #xff))
                                        (is-dir '(#x88 #xcc #xff #xff))
                                        (t      +col-default+)))
                        (content  (format nil "  ~3d  ~a ~va ~8a ~15a"
                                          (1+ idx) prefix
                                          name-cols disp-name fsize fdate)))
                   (sdl:set-render-draw-color *renderer* bg-col)
                   (sdl:render-fill-rect *renderer* (list (1+ box-x) y (- box-w 2) +char-height+))
                   (when sel
                     (sdl:set-render-draw-color *renderer* '(#x40 #x66 #x99 #xff))
                     (sdl:render-fill-rect *renderer* (list box-x y 3 +char-height+)))
                   (cached-render-text-at (box-row content cols) box-x y fg-col))
                 (incf y +char-height+))
        ;; Bottom border
        (cached-render-text-at
         (concatenate 'string (string *box-bl*) hline (string *box-br*)) box-x y)
        (incf y +char-height+)
        ;; Search / rename bar
        (let ((bar-content (if *fb-renaming*
                               (format nil " Rename: ~a_  [Enter=confirm] [Esc=cancel]"
                                       *fb-rename-text*)
                               (format nil " Search: ~a_  [type to filter]"
                                       *fb-search*))))
          (sdl:set-render-draw-color *renderer* '(#x18 #x22 #x2c #xff))
          (sdl:render-fill-rect *renderer* (list (1+ box-x) y (- box-w 2) +char-height+))
          (cached-render-text-at (box-row bar-content cols)
                                 box-x y
                                 (if *fb-renaming* +col-keyword+ +col-string+)))
        (incf y +char-height+)
        ;; Hint line
        (cached-render-text-at
         (box-row "  arrows:nav  Enter:open  Del:delete  ^R:rename  ^N:new file  ^M:mkdir  ^G:goto  Esc:back" cols)
         box-x y +col-comment+))
      ;; Scrollbar
      (render-scrollbar sb-x (+ box-y (* 4 +char-height+))
                        (* visible +char-height+)
                        n visible *fb-scroll*))))

(defun render-help ()
  (when (and *help-active* *renderer*)
    (let* ((cmds    command-frame:*commands*)
           (n-cmds  (length cmds))
           (box-w   (min 700 (max 400 (- *window-width* 40))))
           (max-vis (max 4 (- (floor (- *window-height* (* 8 +char-height+)) +char-height+) 1)))
           (visible (min max-vis n-cmds))
           (box-h   (* (+ visible 4) +char-height+))
           (box-x   (floor (- *window-width* box-w) 2))
           (box-y   (floor (- *window-height* box-h) 2))
           (cols    (max 4 (- (ceiling box-w +char-width+) 2)))
           (hline   (box-hline (max 0 (- (ceiling box-w +char-width+) 2))))
            (sb-x    (+ box-x box-w (- (* 2 +char-width+)) -1)))
      ;; Clamp scroll only when needed
      (when (> *help-scroll* (max 0 (- n-cmds visible)))
        (setf *help-scroll* (max 0 (- n-cmds visible))))
      (when (< *help-scroll* 0)
        (setf *help-scroll* 0))
      (sdl:set-render-draw-color *renderer* '(#x1e #x1e #x2e #xff))
      (sdl:render-fill-rect *renderer* (list box-x box-y box-w box-h))
      (let ((y box-y))
        (cached-render-text-at (concatenate 'string (string *box-tl*) hline (string *box-tr*)) box-x y)
        (incf y +char-height+)
        (cached-render-text-at (box-row (format nil "  Commands  (~a-~a/~a)" (1+ *help-scroll*) (min n-cmds (+ *help-scroll* visible)) n-cmds) (ceiling box-w +char-width+)) box-x y)
        (incf y +char-height+)
        (cached-render-text-at (concatenate 'string (string *box-ml*) hline (string *box-mr*)) box-x y)
        (incf y +char-height+)
        (let ((hcols (ceiling box-w +char-width+)))
          (loop for idx from *help-scroll* below (min n-cmds (+ *help-scroll* visible))
                for entry = (nth idx cmds)
                do (cached-render-text-at
                    (box-row (format nil "  ~a  ~a" (car entry) (cdr entry)) hcols)
                    box-x y)
                   (incf y +char-height+)))
        (cached-render-text-at (concatenate 'string (string *box-bl*) hline (string *box-br*)) box-x y)
        (incf y +char-height+)
        (cached-render-text-at "  ↑↓/wheel to scroll  any key to close" box-x y))
      ;; Scrollbar
      (render-scrollbar sb-x (+ box-y (* 3 +char-height+))
                        (* visible +char-height+)
                        n-cmds visible *help-scroll*))))

(defun render-notifications ()
  (let ((notes (live-notifications)))
    (when notes
      (let ((x (- *window-width* 10)) (y (+ +doc-top+ 4)))
        (dolist (n notes)
          (cached-render-text-at (car n) (- x (* (length (car n)) +char-width+)) y
                                '(#xaa #xcc #xff #xff))
          (incf y +char-height+))))))

(defun render-welcome ()
  (when (and (= (length *document*) 0) (null *current-file*) *renderer*)
    (let* ((art     *welcome-art*)
           (art-h   (length art))
           (usable  (- *window-height* +doc-top+ +status-bar-h+ +border-height+))
           (cy      (max +doc-top+ (+ +doc-top+ (floor (- usable (* art-h +char-height+)) 2)))))
      (loop for line in art for i from 0
            do (when (> (length line) 0)
                 (let* ((lw (* (length line) +char-width+))
                        (lx (max 4 (floor (- *window-width* lw) 2))))
                   (cached-render-text-at line lx (+ cy (* i +char-height+))
                                          (if (< i 12) +col-string+ +col-comment+))))))))

(defun render-search-bar ()
  (when (and *search-active* *renderer*)
    (let* ((n         (length *search-matches*))
           (bar-h     (* 2 +char-height+))
           (bar-y     (- *window-height* +status-bar-h+ +border-height+ bar-h))
           (lbl-x     4)
           (lbl-w     (* 6 +char-width+))    ; "Find: " = 6 chars
           (in-x      (+ lbl-x lbl-w 4))    ; input field start
           (fw        (min 300 (max 120 (- *window-width* in-x 260))))
           (opt-x     (+ in-x fw 8))
           (count-str (if (> n 0)
                          (format nil "~d/~d" (1+ (max 0 *search-current*)) n)
                          "none"))
           (count-col (if (> n 0) +col-string+ +col-comment+)))
      ;; Background
      (sdl:set-render-draw-color *renderer* '(#x12 #x12 #x22 #xff))
      (sdl:render-fill-rect *renderer* (list 0 bar-y *window-width* bar-h))
      (sdl:set-render-draw-color *renderer* '(#x44 #x44 #x66 #xff))
      (sdl:render-fill-rect *renderer* (list 0 bar-y *window-width* 1))
      ;; --- Find row ---
      (let ((fy bar-y))
        (cached-render-text-at "Find: " lbl-x fy +col-keyword+)
        (sdl:set-render-draw-color *renderer* (if (eq *search-focus* :find)
                                                   '(#x28 #x28 #x44 #xff)
                                                   '(#x1c #x1c #x30 #xff)))
        (sdl:render-fill-rect *renderer* (list in-x fy fw +char-height+))
        (cached-render-text-at (format nil "~a_" *search-text*) (+ in-x 2) fy)
        (cached-render-text-at "[Aa]" opt-x fy
                               (if *search-match-case* +col-string+ +col-comment+))
        (cached-render-text-at "[W]"  (+ opt-x 40) fy
                               (if *search-whole-word* +col-string+ +col-comment+))
        (cached-render-text-at count-str (+ opt-x 76) fy count-col)
        (cached-render-text-at "^v Esc" (+ opt-x 128) fy +col-comment+))
      ;; --- Replace row ---
      (let ((ry (+ bar-y +char-height+)))
        (cached-render-text-at "Repl: " lbl-x ry +col-keyword+)
        (sdl:set-render-draw-color *renderer* (if (eq *search-focus* :replace)
                                                   '(#x28 #x28 #x44 #xff)
                                                   '(#x1c #x1c #x30 #xff)))
        (sdl:render-fill-rect *renderer* (list in-x ry fw +char-height+))
        (cached-render-text-at (format nil "~a_" *search-replace-text*) (+ in-x 2) ry)
        (cached-render-text-at "[Tab] [Enter:1] [^A:all]" opt-x ry +col-comment+)))))

;;; ================================================================
;;;  Settings overlay
;;; ================================================================

(defparameter +settings-sections+ '("Appearance" "Autosave" "Font" "Display"))

(defstruct settings-row label field value-fn kind)

(defun settings-rows ()
  (ecase *settings-section*
    (0 (list (make-settings-row :label "Theme" :field :theme :value-fn nil :kind :cycle)
             (make-settings-row :label "Notifications" :field :notifications
                                :value-fn (lambda () (if *notifications-enabled* "ON" "OFF")) :kind :toggle)))
    (1 (list (make-settings-row :label "Autosave" :field :autosave
                                :value-fn (lambda () (if *autosave-enabled* "ON" "OFF")) :kind :toggle)))
    (2 (list (make-settings-row :label "Font path" :field :font-path :kind :text)
             (make-settings-row :label "Font size (px)" :field :font-size
                                :value-fn (lambda () (format nil "~d" (round *font-size-px*))) :kind :number)))
    (3 (list (make-settings-row :label "Default width" :field :win-w
                                :value-fn (lambda () (format nil "~d" *window-width*)) :kind :number)
             (make-settings-row :label "Default height" :field :win-h
                                :value-fn (lambda () (format nil "~d" *window-height*)) :kind :number)
             (make-settings-row :label "FPS overlay" :field :fps
                                :value-fn (lambda () (if *show-fps* "ON" "OFF")) :kind :toggle)
             (make-settings-row :label "Fullscreen" :field :fullscreen
                                :value-fn (lambda () (if *fullscreen* "ON" "OFF")) :kind :toggle)
             (make-settings-row :label "Reset all settings" :field :reset :kind :button)))))

(defun render-settings ()
  (when (and *settings-active* *renderer*)
    (let* ((rows      (settings-rows))
           (n-rows    (length rows))
           (box-w     (min 700 (max 500 (- *window-width* 40))))
           (box-h     (min (- *window-height* 40) (max 300 (round (* *window-height* 0.85)))))
           (box-x     (floor (- *window-width* box-w) 2))
           (box-y     (floor (- *window-height* box-h) 2))
           (cols      (max 10 (ceiling box-w +char-width+)))
           (hline     (box-hline (max 0 (- cols 2))))
           (vis-rows  (max 1 (- (floor (- box-h (* 5 +char-height+)) +char-height+) 1))))
      (setf *settings-row* (max 0 (min *settings-row* (1- n-rows))))
      (when (>= *settings-row* (+ *settings-scroll* vis-rows))
        (setf *settings-scroll* (max 0 (- *settings-row* vis-rows -1))))
      (when (< *settings-row* *settings-scroll*)
        (setf *settings-scroll* *settings-row*))
      ;; Background
      (sdl:set-render-draw-color *renderer* '(#x0e #x0e #x1a #xff))
      (sdl:render-fill-rect *renderer* (list box-x box-y box-w box-h))
      (sdl:set-render-draw-color *renderer* '(#x55 #x55 #x75 #xff))
      (sdl:render-fill-rect *renderer* (list box-x box-y box-w 1))
      (sdl:render-fill-rect *renderer* (list box-x box-y 1 box-h))
      (sdl:render-fill-rect *renderer* (list (+ box-x box-w -1) box-y 1 box-h))
      (sdl:render-fill-rect *renderer* (list box-x (+ box-y box-h -1) box-w 1))
      (let ((y box-y))
        ;; Title
        (cached-render-text-at (box-row "  Settings" cols) box-x y +col-keyword+)
        (incf y +char-height+)
        ;; Section tabs
        (let ((tab-x box-x))
          (loop for i from 0 for name in +settings-sections+
                do (let ((tw (* (+ (length name) 3) +char-width+)))
                     (when (= i *settings-section*)
                       (sdl:set-render-draw-color *renderer* '(#x33 #x44 #x66 #xff))
                       (sdl:render-fill-rect *renderer* (list tab-x y tw +char-height+)))
                     (cached-render-text-at (format nil " ~a " name) (+ tab-x +char-width+) y
                                            (if (= i *settings-section*) '(#xee #xee #xff #xff) +col-comment+))
                     (incf tab-x tw))))
        (incf y +char-height+)
        ;; Divider
        (cached-render-text-at (concatenate 'string (string *box-ml*) hline (string *box-mr*)) box-x y)
        (incf y +char-height+)
        ;; Rows
        (loop for idx from *settings-scroll* below (min n-rows (+ *settings-scroll* vis-rows))
              do (let* ((row (nth idx rows))
                        (sel (= idx *settings-row*))
                        (val (let ((vf (settings-row-value-fn row)))
                               (cond (vf (funcall vf))
                                     ((eq (settings-row-field row) :theme)
                                      (symbol-name (if (boundp '*color-theme*) *color-theme* :dark)))
                                     ((eq (settings-row-field row) :font-path)
                                      "[click to edit]")
                                     (t ""))))
                        (label (format nil " ~a" (settings-row-label row)))
                        (kind  (settings-row-kind row))
                        (line  (box-row (format nil " ~va: ~a" 22 label val) cols))
                        (bg    (cond (sel '(#x25 #x38 #x5a #xff)) (t '(#x0e #x0e #x1a #xff))))
                        (fg    (cond (sel '(#xff #xff #xff #xff))
                                     ((eq kind :button) +col-keyword+)
                                     (t +col-default+))))
                   (sdl:set-render-draw-color *renderer* bg)
                   (sdl:render-fill-rect *renderer* (list (1+ box-x) y (- box-w 2) +char-height+))
                   (when sel
                     (sdl:set-render-draw-color *renderer* '(#x40 #x66 #x99 #xff))
                     (sdl:render-fill-rect *renderer* (list box-x y 3 +char-height+)))
                   (cached-render-text-at line box-x y fg)
                   (incf y +char-height+)))
        ;; Help hint
        (cached-render-text-at (box-row "  Enter=toggle  Esc=close  Left/Right=tab" cols) box-x y +col-comment+)))))

(defun settings-activate ()
  (let* ((rows (settings-rows))
         (row (when (< *settings-row* (length rows)) (nth *settings-row* rows))))
    (when row
      (case (settings-row-field row)
        (:autosave (setf *autosave-enabled* (not *autosave-enabled*)) (save-settings)
                   (push-notification (if *autosave-enabled* "Autosave: ON" "Autosave: OFF")))
        (:notifications (setf *notifications-enabled* (not *notifications-enabled*))
                        (push-notification (if *notifications-enabled* "Notifications: ON" "Notifications: OFF")))
        (:fps (setf *show-fps* (not *show-fps*)) (save-settings)
              (push-notification (if *show-fps* "FPS: ON" "FPS: OFF")))
        (:fullscreen (setf *fullscreen* (not *fullscreen*))
                     (when *window* (sdl:set-window-fullscreen *window* *fullscreen*))
                     (save-settings)
                     (push-notification (if *fullscreen* "Fullscreen: ON" "Fullscreen: OFF")))
        (:reset (setf *autosave-enabled* t *show-fps* nil *fullscreen* nil
                      *notifications-enabled* t *color-theme* :dark)
                (save-settings)
                (push-notification "Settings reset to defaults"))
        (:font-path nil)
        (:font-size nil)
        (:win-w nil)
        (:win-h nil)
        (:theme nil)))))

(defun settings-handle-key (scancode key ctrl)
  (cond
    ;; Enter = activate toggle/button
    ((= key (char-code #\Return)) (settings-activate))
    ;; Esc = close settings
    ((= key (char-code #\Esc)) (setf *settings-active* nil))
    ;; Tab = next section
    ((= scancode 43)
     (setf *settings-section* (mod (1+ *settings-section*) (length +settings-sections+))
           *settings-row* 0 *settings-scroll* 0))
    ;; Up/down = navigate rows
    ((or (= scancode 82) (= scancode 96))  ; Up
     (when (> *settings-row* 0) (decf *settings-row*)))
    ((or (= scancode 81) (= scancode 90))  ; Down
     (when (< *settings-row* (1- (length (settings-rows)))) (incf *settings-row*)))
    ;; Left/right = switch section tabs
    ((or (= scancode 80) (= scancode 92))  ; Left
     (setf *settings-section* (max 0 (1- *settings-section*))
           *settings-row* 0 *settings-scroll* 0))
    ((or (= scancode 79) (= scancode 94))  ; Right
     (setf *settings-section* (min (1- (length +settings-sections+)) (1+ *settings-section*))
           *settings-row* 0 *settings-scroll* 0))))

(defun tab-positions ()
  "Return list of (left-x width close-x) for each tab."
  (let ((x 0))
    (mapcar (lambda (tab)
              (let* ((name (tab-name tab))
                     (w    (* (+ (length name) 4) +char-width+)))  ; name + space + x + space
                (prog1 (list x w (+ x (* (+ (length name) 2) +char-width+)))
                  (incf x w))))
            *tabs*)))

(defun render-tab-bar ()
  (when (null *renderer*) (return-from render-tab-bar))
  (let ((y +menu-height+))
    (sdl:set-render-draw-color *renderer* '(#x18 #x18 #x28 #xff))
    (sdl:render-fill-rect *renderer* (list 0 y *window-width* +tab-height+))
    (sdl:set-render-draw-color *renderer* '(#x44 #x44 #x55 #xff))
    (sdl:render-fill-rect *renderer* (list 0 (+ y (1- +tab-height+)) *window-width* 1))
    (loop for i from 0 for tab in *tabs*
          for (tx tw close-x) in (tab-positions)
          do (let* ((name   (tab-name tab))
                    (active (= i *current-tab*))
                    (ty     (floor (- +tab-height+ +char-height+) 2))
                    (closing-hover (= i *tab-close-hover*)))
               ;; Tab background
               (if active
                   (sdl:set-render-draw-color *renderer* '(#x33 #x44 #x66 #xff))
                   (sdl:set-render-draw-color *renderer* '(#x1e #x1e #x2e #xff)))
               (sdl:render-fill-rect *renderer* (list tx y tw +tab-height+))
               ;; Active indicator bar
               (when active
                 (sdl:set-render-draw-color *renderer* '(#x55 #x88 #xcc #xff))
                 (sdl:render-fill-rect *renderer* (list tx y tw 2)))
               ;; Tab name
               (cached-render-text-at name (+ tx +char-width+) (+ y ty)
                                      (if active '(#xee #xee #xff #xff)
                                          '(#x88 #x88 #x99 #xff)))
               ;; Close X — red if hovering
               (when closing-hover
                 (sdl:set-render-draw-color *renderer* '(#x99 #x22 #x22 #xff))
                 (sdl:render-fill-rect *renderer* (list close-x y (* 2 +char-width+) +tab-height+)))
               (cached-render-text-at "x" (+ close-x (floor +char-width+ 2)) (+ y ty)
                                      (if closing-hover '(#xff #x88 #x88 #xff)
                                          '(#x66 #x66 #x77 #xff)))))))

(defun render-menu-bar ()
  (when (null *renderer*) (return-from render-menu-bar))
  (sdl:set-render-draw-color *renderer* '(#x22 #x22 #x2e #xff))
  (sdl:render-fill-rect *renderer* (list 0 0 *window-width* +menu-height+))
  (sdl:set-render-draw-color *renderer* '(#x55 #x55 #x75 #xff))
  (sdl:render-fill-rect *renderer* (list 0 (1- +menu-height+) *window-width* 1))
  (loop for i from 0 for menu in *menus*
        for (mx mw) in (menu-title-x-positions)
        do (progn
             (when (eql *menu-open* i)
               (sdl:set-render-draw-color *renderer* '(#x33 #x55 #x88 #xff))
               (sdl:render-fill-rect *renderer* (list mx 0 mw +menu-height+)))
             (cached-render-text-at (first menu) (+ mx (floor +char-width+ 2)) (floor (- +menu-height+ +char-height+) 2)))
  (when *menu-open*
    (let* ((positions (menu-title-x-positions))
           (mx (first (nth *menu-open* positions)))
           (items (rest (nth *menu-open* *menus*)))
           (dw (dropdown-width *menu-open*))
           (dy +menu-height+))
      (sdl:set-render-draw-color *renderer* '(#x25 #x25 #x35 #xff))
      (sdl:render-fill-rect *renderer* (list mx dy dw (* (length items) +char-height+)))
      (sdl:set-render-draw-color *renderer* '(#x55 #x55 #x75 #xff))
      (sdl:render-fill-rect *renderer* (list mx dy dw 1))
      (sdl:render-fill-rect *renderer* (list mx dy 1 (* (length items) +char-height+)))
      (sdl:render-fill-rect *renderer* (list (+ mx dw -1) dy 1 (* (length items) +char-height+)))
      (loop for j from 0 for item in items
            for iy = (+ dy (* j +char-height+))
            do (progn
                 (when (eql *menu-hover* j)
                   (sdl:set-render-draw-color *renderer* '(#x33 #x55 #x99 #xff))
                   (sdl:render-fill-rect *renderer* (list (1+ mx) iy (- dw 2) +char-height+)))
                 (if (eq (first item) :sep)
                     (cached-render-text-at (box-hline (floor dw +char-width+)) mx iy)
                     (let* ((itype   (first item))
                            (label   (second item))
                            (var-sym (fourth item))
                            (state   (if (and (eq itype :toggle) var-sym)
                                         (if (symbol-value var-sym) " ON" " OFF")
                                         ""))
                            (text    (format nil " ~a~a" label state)))
                       (cached-render-text-at text (1+ mx) iy)))))))))

;;; ---- Main render ----

(defun render-state ()
  (when (null *renderer*) (return-from render-state))
  (unless *fps* (setf *fps* (make-fps)))
  (when (fps-tick *fps*) (setf *last-fps* (fps-state-fps *fps*)))
  (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
    (when (or (/= rw *prev-win-w*) (/= rh *prev-win-h*))
      (setf *prev-win-w* rw *prev-win-h* rh
            *window-resize-time* (sdl:get-ticks)))
    (setf *window-width* rw *window-height* rh))
  ;; Keep tab struct in sync with live state each frame
  (save-current-tab)
  (sdl:set-render-draw-color *renderer* '(#x1e #x1e #x1e #xff))
  (sdl:render-clear *renderer*)
  (render-document)
  (render-welcome)
  (render-cursor)
  (render-tab-bar)
  (render-menu-bar)
  (render-status-bar)
  (render-dim-overlay)
  (render-file-browser)
  (render-help)
  (render-search-bar)
  (render-settings)
  (render-notifications)
  (when (command-frame:show-p) (command-frame:render))
  (when (and *last-fps* *show-fps*)
    (cached-render-text-at (format nil "~d FPS" (round *last-fps*))
                           (- *window-width* 64) +menu-height+))
  ;; Resize notification overlay (2 seconds)
  (when (and (> *window-resize-time* 0)
             (< (- (sdl:get-ticks) *window-resize-time*) 2000))
    (let* ((tc (floor *window-width* +char-width+))
           (tr (floor *window-height* +char-height+))
           (msg (format nil " ~dx~d px | ~dx~d chars " *window-width* *window-height* tc tr))
           (mw  (* (length msg) +char-width+))
           (mx  (floor (- *window-width* mw) 2))
           (my  (floor (- *window-height* +char-height+) 2)))
      (sdl:set-render-draw-color *renderer* '(#x00 #x00 #x00 #xcc))
      (sdl:render-fill-rect *renderer* (list (- mx 4) (- my 4) (+ mw 8) (+ +char-height+ 8)))
      (cached-render-text-at msg mx my '(#xff #xff #x88 #xff))))
  (sdl:render-present *renderer*))

;;; ================================================================
;;;  Event handlers
;;; ================================================================

(defun event-summary (event etype)
  "Return a short one-line summary for EVENT of type ETYPE.
This uses safe calls (ignore-errors) so reporting never fails." 
  (handler-case
      (cond
        ((eq etype :key-down)
         (let ((sc (ignore-errors (sdl:keyboard-event-scancode event)))
               (k  (ignore-errors (sdl:keyboard-event-key event)))
               (m  (ignore-errors (sdl:keyboard-event-mod event))))
           (format nil "key-down sc=~a key=~a mod=~a" sc k m)))
        ((eq etype :text-input)
         (let ((txt (ignore-errors (sdl:text-input-event-text event))))
           (format nil "text-input text=~a" (or txt ""))))
        ((eq etype :mouse-button-down)
         (let ((x (ignore-errors (sdl:mouse-button-event-x event)))
               (y (ignore-errors (sdl:mouse-button-event-y event)))
               (b (ignore-errors (sdl:mouse-button-event-button event))))
           (format nil "mouse-down x=~a y=~a btn=~a" x y b)))
        ((eq etype :mouse-motion)
         (let ((x (ignore-errors (sdl:mouse-motion-event-x event)))
               (y (ignore-errors (sdl:mouse-motion-event-y event))))
           (format nil "mouse-motion x=~a y=~a" x y)))
        (t (format nil "~a" etype)))
    (error (e) (format nil "event-summary-failed: ~S" e))))

(defun report-error (condition &optional context)
  "Centralised error reporting: print to *error-output*, append `error.log`,
push a short notification and attempt to print a backtrace if available." 
  (let ((ctx (or context "")))
    (format *error-output* "~&[ERROR] ~a~%" ctx)
    (format *error-output* "~&Condition: ~S~%" condition)
    ;; Append short entry to error.log in project cwd
    (handler-case
        (with-open-file (f (merge-pathnames #p"error.log" (uiop:getcwd))
                           :direction :output :if-exists :append :if-does-not-exist :create)
          (format f "~&[~a] ~a~%" (get-universal-time) ctx)
          (format f "Condition: ~S~%" condition))
      (error (e) (format *error-output* "~&Failed to write error.log: ~S~%" e)))
    ;; Short user notification (so UI shows an alert)
    (when (fboundp 'push-notification)
      (push-notification (format nil "Error: ~a" (if (and (stringp ctx) (> (length ctx) 0)) ctx (princ-to-string condition)))))
    ;; Try to print a backtrace: prefer sb-debug:BACKTRACE, then sb-ext fallback
    (handler-case
        (let ((pkg (find-package :sb-debug)))
          (cond
            ((and pkg (fboundp (intern "BACKTRACE" pkg)))
             (funcall (intern "BACKTRACE" pkg)))
            ((and pkg (fboundp (intern "PRINT-BACKTRACE" pkg)))
             (funcall (intern "PRINT-BACKTRACE" pkg)))
            (t (format *error-output* "~&Backtrace not available.~%"))))
      (error (e) (format *error-output* "~&Backtrace printing failed: ~S~%" e)))))

(defun handle-quit (event)
  (declare (ignore event))
  (setf *running* nil))

(defun handle-key-down (event)
  (let* ((scancode (or (sdl:keyboard-event-scancode event) 0))
         (mod      (or (sdl:keyboard-event-mod event) 0))
         (key      (or (sdl:get-key-from-scancode scancode mod nil) 0))
         (ctrl     (sdl:mod-ctrl-p mod))
         (shift    (sdl:mod-shift-p mod)))
    (declare (type integer scancode mod key)
             (ignorable ctrl shift))
    (when *help-active*
      (cond
        ((or (= scancode 82) (= scancode 96))  ; Up/KP8
         (decf *help-scroll*))
        ((or (= scancode 81) (= scancode 90))  ; Down/KP2
         (incf *help-scroll*))
        ((or (= scancode 75) (= scancode 97))  ; PageUp/KP9
         (decf *help-scroll* 5))
        ((or (= scancode 78) (= scancode 91))  ; PageDown/KP3
         (incf *help-scroll* 5))
        ((or (= scancode 74) (= scancode 95))  ; Home/KP7
         (setf *help-scroll* 0))
        ((or (= scancode 77) (= scancode 89))  ; End/KP1
         (setf *help-scroll* 9999))
        ((or (= key (char-code #\k)) (= key (char-code #\j))
             (= key (char-code #\h)) (= key (char-code #\l)))  ; hjkl
         (cond ((= key (char-code #\k)) (decf *help-scroll*))
               ((= key (char-code #\j)) (incf *help-scroll*))
               ((= key (char-code #\h)) (decf *help-scroll* 5))
               ((= key (char-code #\l)) (incf *help-scroll* 5))))
        (t (setf *help-active* nil)))
      (return-from handle-key-down))
    ;; Settings overlay
    (when *settings-active*
      (settings-handle-key scancode key ctrl)
      (return-from handle-key-down))
    (when *fb-active* (handle-file-browser-key scancode key ctrl) (return-from handle-key-down))
    ;; Search bar key handling
    (when *search-active*
      (cond
        ((= key (char-code #\Esc))
         (setf *search-active* nil))
        ((and (= scancode 82) (not ctrl))  ; Up — prev match
         (search-prev))
        ((and (= scancode 81) (not ctrl))  ; Down — next match
         (search-next))
        ((and (= key (char-code #\Tab)) (not ctrl))
         (setf *search-focus* (if (eq *search-focus* :find) :replace :find)))
        ((= key (char-code #\Return))
         (if (eq *search-focus* :replace)
             (search-replace-current)
             (search-next)))
        ((= key (char-code #\Backspace))
         (if (eq *search-focus* :find)
             (when (> (length *search-text*) 0)
               (setf *search-text* (subseq *search-text* 0 (1- (length *search-text*))))
               (update-search))
             (when (> (length *search-replace-text*) 0)
               (setf *search-replace-text*
                     (subseq *search-replace-text* 0 (1- (length *search-replace-text*)))))))
        ;; Ctrl+A = replace all (in replace focus)
        ((and ctrl (= key (char-code #\a)))
         (when (eq *search-focus* :replace) (search-replace-all)))
        ;; Toggle match case: Ctrl+I
        ((and ctrl (= key (char-code #\i)))
         (setf *search-match-case* (not *search-match-case*)) (update-search))
        ;; Toggle whole word: Ctrl+W (in search mode only)
        ((and ctrl (not shift) (= key (char-code #\w)))
         (setf *search-whole-word* (not *search-whole-word*)) (update-search)))
      (return-from handle-key-down))

    ;; Esc closes menu
    (when (and *menu-open* (= key (char-code #\Esc)))
      (setf *menu-open* nil *menu-hover* nil *menu-keyboard-active* nil)
      (return-from handle-key-down))
    ;; Dropdown click handling via Enter when menu open
    (when (and *menu-open* (= key (char-code #\Return)))
      (let* ((items (rest (nth *menu-open* *menus*)))
             (item (and *menu-hover* (< *menu-hover* (length items)) (nth *menu-hover* items))))
        (setf *menu-open* nil *menu-hover* nil)
        (when (and item (member (first item) '(:item :toggle))) (execute-action (third item))))
      (return-from handle-key-down))
    ;; Ctrl shortcuts
    (when ctrl
      (cond
        ((= key (char-code #\a)) (execute-action :select-all) (return-from handle-key-down))
        ((= key (char-code #\c)) (execute-action :copy) (return-from handle-key-down))
        ((= key (char-code #\x)) (execute-action :cut) (return-from handle-key-down))
        ((= key (char-code #\v)) (execute-action :paste) (return-from handle-key-down))
        ((and shift (= key (char-code #\z)))
         (execute-action :redo) (return-from handle-key-down))
        ((= key (char-code #\z)) (execute-action :undo) (return-from handle-key-down))
        ((= key (char-code #\y)) (execute-action :redo) (return-from handle-key-down))
        ((and shift (= key (char-code #\t)))
         (restore-tab) (return-from handle-key-down))
        ((= key (char-code #\t)) (new-tab) (return-from handle-key-down))
        ((and shift (= key (char-code #\w)))
         (set-running nil) (return-from handle-key-down))
        ((= key (char-code #\w)) (close-tab) (return-from handle-key-down))
        ((= key (char-code #\f))
         (setf *search-active* t *search-text* "" *search-replace-text* ""
               *search-matches* nil *search-current* -1 *search-focus* :find)
         (return-from handle-key-down))
        ((= key (char-code #\r))
         (if *fb-active*
             (progn
               (let* ((f (fb-filtered-entries))
                      (entry (when (< *fb-cursor* (length f)) (nth *fb-cursor* f))))
                 (when (and entry (not (string= (first entry) "..")))
                   (setf *fb-renaming* t *fb-rename-text* (first entry)))))
             ;; In text editor: open rename command
             (if *current-file*
                 (command-frame:show (format nil "/rename ~a" (file-namestring *current-file*)))
                 (set-message "No file open — use Ctrl+Shift+S to save first")))
         (return-from handle-key-down))
        ((= key (char-code #\n)) (new-tab) (return-from handle-key-down))
        ((and shift (= key (char-code #\s)))
         (command-frame:show "/w ") (return-from handle-key-down))
        ((and shift (= key (char-code #\p)))
         (command-frame:show "/") (return-from handle-key-down))
        ((= key (char-code #\s)) (execute-action :save-file) (return-from handle-key-down))
        ((= key (char-code #\o)) (open-file-browser) (return-from handle-key-down))
        ;; Ctrl+Tab / Ctrl+Shift+Tab = next/prev tab
        ((= scancode 43)  ; Tab
         (if shift
             (switch-tab (max 0 (1- *current-tab*)))
             (switch-tab (min (1- (length *tabs*)) (1+ *current-tab*))))
         (return-from handle-key-down))
        ;; Ctrl+` = toggle to last tab
        ((= key (char-code #\`))
         (when (and (>= *last-tab* 0) (< *last-tab* (length *tabs*)))
           (switch-tab *last-tab*))
         (return-from handle-key-down))
        ;; Ctrl+1..9 = switch to tab N, Ctrl+0 = last tab
        ((and (>= key (char-code #\0)) (<= key (char-code #\9))
              (not shift))
         (let ((n (if (= key (char-code #\0))
                      (1- (length *tabs*))  ; last tab
                      (- key (char-code #\1)))))  ; 0-8 for keys 1-9
           (when (and (>= n 0) (< n (length *tabs*)))
             (switch-tab n)))
         (return-from handle-key-down))))
    ;; Command frame open
    (when (command-frame:show-p)
      ;; Pass special keys (including Tab for autocomplete) to command frame
      (when (or (= key (char-code #\Esc)) (= key (char-code #\Return))
                (= key (char-code #\Tab)) (= key (char-code #\Backspace)) (= key 127))
        (command-frame:handle-key key))
      (return-from handle-key-down))
    ;; Open command frame: ; : / Insert ` (normal mode only)
    (when (and (eq *mode* :normal)
               (or (= key (char-code #\;)) (= key (char-code #\:))
                   (= key (char-code #\/)) (= key (char-code #\`))
                   (= scancode 73)))
      (command-frame:show) (return-from handle-key-down))
    ;; F1..F6 open/toggle top-level menus
    (when (and (>= scancode 58) (<= scancode 63))
      (let ((mi (- scancode 58)))
        (if (eql *menu-open* mi)
            (setf *menu-open* nil *menu-hover* nil *menu-keyboard-active* nil)
            (setf *menu-open* mi *menu-hover* 0 *menu-keyboard-active* t))
        (return-from handle-key-down)))
    ;; F11 fullscreen toggle
    (when (= scancode 68)
      (setf *fullscreen* (not *fullscreen*))
      (when *window* (sdl:set-window-fullscreen *window* *fullscreen*))
      (return-from handle-key-down))
    ;; Navigation keys: menus / help / cursor
    (cond
      ;; --- Menu open: navigate dropdown ---
      ((and *menu-open* (or (= scancode 82) (= scancode 96))) ; Up / KP8
       (let* ((items (rest (nth *menu-open* *menus*))) (n (length items)))
         (setf *menu-hover*
               (if (or (null *menu-hover*) (zerop *menu-hover*)) (1- n) (1- *menu-hover*))))
       (return-from handle-key-down))
      ((and *menu-open* (or (= scancode 81) (= scancode 90))) ; Down / KP2
       (let* ((items (rest (nth *menu-open* *menus*))) (n (length items)))
         (setf *menu-hover*
               (if (or (null *menu-hover*) (>= *menu-hover* (1- n))) 0 (1+ *menu-hover*))))
       (return-from handle-key-down))
      ((and *menu-open* (or (= scancode 80) (= scancode 92))) ; Left / KP4
       (setf *menu-open* (max 0 (1- *menu-open*)) *menu-hover* 0)
       (return-from handle-key-down))
      ((and *menu-open* (or (= scancode 79) (= scancode 94))) ; Right / KP6
       (setf *menu-open* (min (1- (length *menus*)) (1+ *menu-open*)) *menu-hover* 0)
       (return-from handle-key-down))
      ((and *menu-open* (or (= scancode 74) (= scancode 95))) ; Home / KP7 — first item
       (setf *menu-hover* 0) (return-from handle-key-down))
      ((and *menu-open* (or (= scancode 77) (= scancode 89))) ; End / KP1 — last item
       (setf *menu-hover* (max 0 (1- (length (rest (nth *menu-open* *menus*))))))
       (return-from handle-key-down))
      ;; --- Help overlay scroll ---
      ((and *help-active* (or (= scancode 82) (= scancode 96)))
       (decf *help-scroll*) (return-from handle-key-down))
      ((and *help-active* (or (= scancode 81) (= scancode 90)))
       (incf *help-scroll*) (return-from handle-key-down))
      ((and *help-active* (or (= scancode 75) (= scancode 97))) ; PageUp / KP9
       (decf *help-scroll* 5) (return-from handle-key-down))
      ((and *help-active* (or (= scancode 78) (= scancode 91))) ; PageDown / KP3
       (incf *help-scroll* 5) (return-from handle-key-down))
      ((and *help-active* (or (= scancode 74) (= scancode 95))) ; Home / KP7
       (setf *help-scroll* 0) (return-from handle-key-down))
      ((and *help-active* (or (= scancode 77) (= scancode 89))) ; End / KP1
       (setf *help-scroll* 9999) (return-from handle-key-down))
      ;; --- File browser scroll ---
      ((and *fb-active* (or (= scancode 75) (= scancode 97))) ; PageUp / KP9
       (setf *fb-cursor* (max 0 (- *fb-cursor* 5))) (return-from handle-key-down))
      ((and *fb-active* (or (= scancode 78) (= scancode 91))) ; PageDown / KP3
       (setf *fb-cursor* (min (max 0 (1- (length *fb-entries*))) (+ *fb-cursor* 5)))
       (return-from handle-key-down))
      ((and *fb-active* (or (= scancode 74) (= scancode 95))) ; Home / KP7
       (setf *fb-cursor* 0) (return-from handle-key-down))
      ((and *fb-active* (or (= scancode 77) (= scancode 89))) ; End / KP1
       (setf *fb-cursor* (max 0 (1- (length *fb-entries*)))) (return-from handle-key-down))
      ;; --- Global cursor movement ---
      ((or (= scancode 80) (= scancode 92)) ; Left / KP4
       (execute-action :move-left)  (return-from handle-key-down))
      ((or (= scancode 79) (= scancode 94)) ; Right / KP6
       (execute-action :move-right) (return-from handle-key-down))
      ((or (= scancode 82) (= scancode 96)) ; Up / KP8
       (execute-action :move-up)    (return-from handle-key-down))
      ((or (= scancode 81) (= scancode 90)) ; Down / KP2
       (execute-action :move-down)  (return-from handle-key-down))
      ((or (= scancode 75) (= scancode 97)) ; PageUp / KP9
       (execute-action :page-up)    (return-from handle-key-down))
      ((or (= scancode 78) (= scancode 91)) ; PageDown / KP3
       (execute-action :page-down)  (return-from handle-key-down))
      ((or (= scancode 74) (= scancode 95)) ; Home / KP7
       (execute-action :move-line-start) (return-from handle-key-down))
       ((or (= scancode 77) (= scancode 89)) ; End / KP1
        (execute-action :move-line-end)   (return-from handle-key-down)))
    ;; Tab = cycle modes (works in all modes)
    (when (= scancode 43)
      (cond
        ((eq *mode* :normal) (execute-action :insert-mode))
        ((eq *mode* :insert) (execute-action :visual-mode))
        (t (execute-action :normal-mode)))
      (return-from handle-key-down))
    ;; Insert mode special keys
    (when (eq *mode* :insert)
      (cond
        ((= key (char-code #\Esc))
         (execute-action :normal-mode))
        ((= key (char-code #\Backspace))
         (when (> *cursor-pos* 0) (delete-range (1- *cursor-pos*) *cursor-pos*) (scroll-to-cursor)))
        ((= key (char-code #\Return))
         (insert-text (string #\Newline)) (scroll-to-cursor))
        ((= key 127)   ; Delete
         (when (< *cursor-pos* (doc-length))
           (delete-range *cursor-pos* (1+ *cursor-pos*)) (scroll-to-cursor))))
      (return-from handle-key-down))
    ;; Normal mode Vim-style keys
    (when (eq *mode* :normal)
      (cond
        ((= key (char-code #\h)) (execute-action :move-left))
        ((= key (char-code #\j)) (execute-action :move-down))
        ((= key (char-code #\k)) (execute-action :move-up))
        ((= key (char-code #\l)) (execute-action :move-right))
        ((= key (char-code #\w)) (execute-action :move-word-forward))
        ((= key (char-code #\b)) (execute-action :move-word-backward))
        ((= key (char-code #\0)) (execute-action :move-line-start))
        ((= key 36)              (execute-action :move-line-end))   ; $
        ((= key (char-code #\i)) (execute-action :insert-mode))
        ((= key (char-code #\a)) (execute-action :move-right) (execute-action :insert-mode))
        ((= key (char-code #\A)) (execute-action :move-line-end) (execute-action :insert-mode))
        ((= key (char-code #\I)) (execute-action :move-line-start) (execute-action :insert-mode))
        ((= key (char-code #\o))
         (execute-action :move-line-end)
         (insert-text (string #\Newline)) (scroll-to-cursor)
         (execute-action :insert-mode))
        ((= key (char-code #\v)) (execute-action :visual-mode))
        ((= key (char-code #\u)) (execute-action :undo))
        ((= key 18)              (execute-action :redo))  ; Ctrl-R handled above; plain r = replace TODO
        ((= key (char-code #\x))
         (when (< *cursor-pos* (doc-length))
           (delete-range *cursor-pos* (1+ *cursor-pos*))))
        ((= key (char-code #\p)) (execute-action :paste))
        ((= key (char-code #\G)) (setf *cursor-pos* (doc-length)) (scroll-to-cursor))
        ((= key (char-code #\Esc)) (clear-selection)))
      (return-from handle-key-down))
    ;; Visual mode Vim-style keys
    (when (eq *mode* :visual)
      (cond
        ((= key (char-code #\h)) (execute-action :move-left))
        ((= key (char-code #\j)) (execute-action :move-down))
        ((= key (char-code #\k)) (execute-action :move-up))
        ((= key (char-code #\l)) (execute-action :move-right))
        ((= key (char-code #\w)) (execute-action :move-word-forward))
        ((= key (char-code #\b)) (execute-action :move-word-backward))
        ((= key (char-code #\y)) (execute-action :copy) (execute-action :normal-mode))
        ((= key (char-code #\d)) (execute-action :cut) (execute-action :normal-mode))
        ((= key (char-code #\x)) (execute-action :cut) (execute-action :normal-mode))
        ((= key (char-code #\p)) (execute-action :paste) (execute-action :normal-mode))
        ((= key (char-code #\Esc)) (execute-action :normal-mode)))
      (return-from handle-key-down))))

(defun handle-text-input (event)
  (let ((text (sdl:text-input-event-text event)))
    (when (and text (> (length text) 0))
      (cond
        (*help-active* nil)
        (*search-active*
         (if (eq *search-focus* :find)
             (progn (setf *search-text* (concatenate 'string *search-text* text))
                    (update-search))
             (setf *search-replace-text* (concatenate 'string *search-replace-text* text))))
        (*fb-active*
         (if *fb-renaming*
             (setf *fb-rename-text* (concatenate 'string *fb-rename-text* text))
             (setf *fb-search* (concatenate 'string *fb-search* text)
                   *fb-cursor* 0 *fb-scroll* 0)))
        ((command-frame:show-p) (command-frame:handle-text text))
        ((or *menu-open*) nil)
        ((eq *mode* :insert) (delete-selection) (insert-text text) (scroll-to-cursor))))))

(defun handle-mouse-button-down (event)
  (let* ((x (round (sdl:mouse-button-event-x event)))
         (y (round (sdl:mouse-button-event-y event)))
         (btn (sdl:mouse-button-event-button event)))
    (when (= btn 1)
      (cond
        ;; Tab bar click
        ((and (>= y +menu-height+) (< y +doc-top+))
         (loop for i from 0 for (tx tw close-x) in (tab-positions)
               do (cond
                    ;; Click on X button = close tab
                    ((and (>= x close-x) (< x (+ close-x (* 2 +char-width+))))
                     (let ((saved-tab *current-tab*))
                       (switch-tab i)
                       (close-tab)
                       (when (< saved-tab (length *tabs*))
                         (switch-tab saved-tab)))
                     (return))
                    ;; Click on tab body = switch to it
                    ((and (>= x tx) (< x (+ tx tw)))
                     (switch-tab i)
                     (return))))
         (setf *menu-open* nil *menu-hover* nil))
        ;; Menu bar click
        ((< y +menu-height+)
         (let ((mi (find-menu-at-x x)))
           (if mi
               (setf *menu-open* (if (eql *menu-open* mi) nil mi) *menu-hover* nil)
               (setf *menu-open* nil *menu-hover* nil))))
        ;; Dropdown item click
        ((and *menu-open* (>= y +menu-height+))
         (let* ((positions (menu-title-x-positions))
                (mx (first (nth *menu-open* positions)))
                (dw (dropdown-width *menu-open*))
                (items (rest (nth *menu-open* *menus*))))
           (if (and (>= x mx) (< x (+ mx dw))
                    (< y (+ +menu-height+ (* (length items) +char-height+))))
               (let* ((dy (- y +menu-height+))
                      (row (floor dy +char-height+))
                      (item (and (< row (length items)) (nth row items))))
                  (setf *menu-open* nil *menu-hover* nil)
                  (when (and item (member (first item) '(:item :toggle)))
                    (execute-action (third item))))
                (setf *menu-open* nil *menu-hover* nil))))
         ;; Help overlay click — close it
         (*help-active*
          (setf *help-active* nil))
         ;; Settings overlay click
         (*settings-active*
          (return-from handle-mouse-button-down))
         ;; Search bar click
         ((and *search-active* (>= y (- *window-height* +status-bar-h+ +border-height+ (* 2 +char-height+))))
          (let* ((lbl-w (* 6 +char-width+))
                 (in-x (+ 4 lbl-w 4))
                 (fw (min 300 (max 120 (- *window-width* in-x 260))))
                 (opt-x (+ in-x fw 8))
                 (find-y (- *window-height* +status-bar-h+ +border-height+ (* 2 +char-height+)))
                 (repl-y (+ find-y +char-height+)))
            (cond
              ((and (>= y find-y) (< y (+ find-y +char-height+)))
               (setf *search-focus* :find))
              ((and (>= y repl-y) (< y (+ repl-y +char-height+)))
               (setf *search-focus* :replace))
              ;; Click on [Aa] button
              ((and (>= y find-y) (< y (+ find-y +char-height+))
                    (>= x opt-x) (< x (+ opt-x 32)))
               (setf *search-match-case* (not *search-match-case*)) (update-search))
              ;; Click on [W] button
              ((and (>= y find-y) (< y (+ find-y +char-height+))
                    (>= x (+ opt-x 40)) (< x (+ opt-x 72)))
               (setf *search-whole-word* (not *search-whole-word*)) (update-search)))))
         ;; Settings overlay click
         ((and *settings-active*)
          (return-from handle-mouse-button-down))
        (t
         (when *menu-open* (setf *menu-open* nil *menu-hover* nil))
         (unless (or *fb-active* *help-active* (command-frame:show-p))
           (when (< y (- *window-height* +status-bar-h+))
             (let ((new-pos (pixel-to-pos x y)))
               (clear-selection)
               (setf *cursor-pos* new-pos *mouse-dragging* t *shift-sel-anchor* new-pos)
               (reset-blink)))))))))

(defun handle-mouse-button-up (event)
  (when (= (sdl:mouse-button-event-button event) 1)
    (setf *mouse-dragging* nil)))

(defun handle-mouse-motion (event)
  (let ((x (round (sdl:mouse-motion-event-x event)))
        (y (round (sdl:mouse-motion-event-y event))))
    ;; Tab close hover tracking
    (setf *tab-close-hover* -1)
    (when (and (>= y +menu-height+) (< y +doc-top+))
      (loop for i from 0 for (tx tw close-x) in (tab-positions)
            do (when (and (>= x close-x) (< x (+ close-x (* 2 +char-width+))))
                 (setf *tab-close-hover* i) (return))))
    (cond
      ;; Menu hover while dropdown open
      ((and *menu-open* (< y +menu-height+))
       (let ((mi (find-menu-at-x x)))
         (when (and mi (not (eql mi *menu-open*)))
           (setf *menu-open* mi *menu-hover* nil))))
      ;; Dropdown item hover
      ((and *menu-open* (>= y +menu-height+))
       (let* ((positions (menu-title-x-positions))
              (mx (first (nth *menu-open* positions)))
              (dw (dropdown-width *menu-open*))
              (items (rest (nth *menu-open* *menus*))))
         (if (and (>= x mx) (< x (+ mx dw))
                  (< y (+ +menu-height+ (* (length items) +char-height+))))
             (setf *menu-hover* (let ((row (floor (- y +menu-height+) +char-height+)))
                                   (and (< row (length items)) row)))
             (setf *menu-hover* nil))))
      ;; Document drag
      (*mouse-dragging*
       (when (and (> y +menu-height+) (< y (- *window-height* +status-bar-h+)))
         (let ((new-pos (pixel-to-pos x y)))
           (unless (= new-pos *shift-sel-anchor*)
             (setf *shift-sel-active* t *cursor-pos* new-pos))))))))

(defun doc-max-scroll ()
  (let* ((total-lines (1+ (count #\Newline *document*)))
         (total-h     (* total-lines +char-height+))
         (visible-h   (- *window-height* +doc-top+ +status-bar-h+ +border-height+)))
    (max 0 (- total-h visible-h))))

(defun handle-mouse-wheel (event)
  (let* ((dy (sdl:mouse-wheel-event-y event))
         (delta (round dy)))
    (cond
      (*help-active*
       (setf *help-scroll* (max 0 (- *help-scroll* delta))))
      (*fb-active*
       (let* ((filtered (fb-filtered-entries))
              (n (length filtered)))
         (setf *fb-cursor* (max 0 (min (max 0 (1- n)) (- *fb-cursor* delta))))))
      (t
       (setf *scroll-y* (max 0 (min (doc-max-scroll)
                                     (- *scroll-y* (* delta +char-height+)))))))))

;;; ================================================================
;;;  Plugin support
;;; ================================================================

(defun load-plugins ()
  (when (and *plugins-dir* (probe-file *plugins-dir*))
    (dolist (f (uiop:directory-files *plugins-dir* "*.lisp"))
      (handler-case
          (progn
            (load f)
            (push-notification (format nil "Loaded plugin: ~a" (file-namestring f))))
        (error (e)
          (push-notification (format nil "Plugin error (~a): ~a" (file-namestring f) e)))))))

(defun load-plugin (path)
  (handler-case
      (progn
        (load path)
        (push-notification (format nil "Loaded: ~a" (file-namestring path))))
    (error (e)
      (push-notification (format nil "Plugin error: ~a" e)))))

;;; ================================================================
;;;  Main loop
;;; ================================================================

(defun handle-drop-file (event)
  (let ((path (sdl:drop-event-data event)))
    (when (and path (> (length path) 0))
      (handler-case
          (open-file path)
        (error (e)
          (push-notification (format nil "Cannot open dropped file: ~a" e)))))))

(defun loop-events ()
  (sdl:start-text-input *window*)
  (loop while *running*
        do (cffi:with-foreign-object (event :uint8 sdl:+event-size+)
             (loop while (sdl:poll-event event)
                   do (let ((etype (sdl:event-type event)))
                        (handler-case
                            (case etype
                              (:quit (handle-quit event))
                              (:key-down (handle-key-down event))
                              (:text-input (handle-text-input event))
                              (:mouse-button-down (handle-mouse-button-down event))
                              (:mouse-button-up (handle-mouse-button-up event))
                              (:mouse-motion (handle-mouse-motion event))
                              (:mouse-wheel (handle-mouse-wheel event))
                              (:drop-file (handle-drop-file event))
                              (:window-focus-gained (setf *window-focused* t))
                              (:window-focus-lost   (setf *window-focused* nil)))
                          (error (e)
                            (let ((ctx (format nil "Event handler error: ~a -- ~a" etype (event-summary event etype))))
                              (report-error e ctx)))))))
        (render-state)))

(defun main ()
  (sdl:init '(:video :events))
  (sdl:ttf-init)
  (let* ((saved-size (load-window-size))
         (init-w (or (first saved-size) 800))
         (init-h (or (second saved-size) 600)))
  (multiple-value-bind (rst window *renderer*)
      (sdl:create-window-and-renderer "ViMDav Text Editor" init-w init-h '(:resizable))
    (if rst
        (progn
          (setf *window* window)
          (sdl:set-render-vsync *renderer* 1)
          (get-font) (init-box-drawing) (load-settings)
          (load-plugins)
          ;; Initialize with one default tab
          (setf *tabs* (list (make-tab-state :mode :insert))
                *current-tab* 0)
          (load-tab 0)
          (format t "Text editor started~%")
          (sdl:set-render-draw-blend-mode *renderer* 1)  ; SDL_BLENDMODE_BLEND
          (loop-events)
          (save-settings)  ; persist session on exit
          (sdl:destroy-renderer *renderer*)
          (sdl:destroy-window window))
        (format *error-output* "SDL Error: ~a~%" (sdl:get-error)))
    (sdl:ttf-quit)
    (sdl:quit))))

(export 'main)