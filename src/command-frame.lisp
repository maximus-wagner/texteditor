(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :command-frame)
    (defpackage :command-frame
      (:use :cl :state :utils)
      )))
(in-package :command-frame)

(defvar *show* nil)
(export '*show*)
(defvar *input-text* "")
(defvar *cmd-just-opened* nil)   ; swallow the trigger character text-input event
(defvar *tab-complete-idx* -1)   ; cycles through Tab completions
(defparameter *cursor* (make-instance 'cursor:cursor))

;;; ---- Visibility ----

(defun show-p () *show*)
(export 'show-p)

(defun show (&optional (prefix "/"))
  (setf *show* t *input-text* prefix *cmd-just-opened* t *tab-complete-idx* -1))
(export 'show)

(export 'reset)

(defun reset ()
  (setf *show* nil *input-text* "" *tab-complete-idx* -1))

;;; ---- Command list (shown by /commands) ----

(defparameter *commands*
  '(("/quit"                    . "Exit the editor")
    ("/fps"                     . "Toggle FPS counter display")
    ("/font <path>"             . "Load a TTF font from PATH")
    ("/open [path]"             . "Browse files or open PATH directly")
    ("/e [path]"                . "Edit file (alias for /open)")
    ("/w [path]"                . "Write/save current file (optional new PATH)")
    ("/bind <mode> <key> <act>" . "Rebind a key in normal / insert / visual mode")
    ("/notif"                   . "Toggle real-time notification display")
    ("/rename <new-name>"       . "Rename current file to NEW-NAME")
    ("/cd [path]"               . "Change working directory (default: home)")
    ("/ls [path]"               . "Open file browser at PATH (or cwd)")
    ("/pwd"                     . "Print current working directory")
    ("/mkdir <name>"            . "Create a new directory in cwd")
    ("/touch <name>"            . "Create a new empty file in cwd")
    ("/rm <name>"               . "Delete a file or empty directory in cwd")
    ("/cp <src> <dst>"          . "Copy a file from SRC to DST")
    ("/commands"                . "Show this command list  (also: /cmd, /cmds)")))
(export '*commands*)

;;; ---- Tab completion helpers ----

(defun cmd-completions (prefix)
  "Return list of command name strings that start with PREFIX."
  (let ((p (string-downcase prefix)))
    (remove-if-not (lambda (c)
                     (let ((name (car c)))
                       (and (<= (length p) (length name))
                            (string= p name :end2 (length p)))))
                   *commands*)))

(defun complete-tab ()
  "Cycle through tab completions for the current input verb."
  (let* ((verb (first (uiop:split-string *input-text* :separator (list #\Space))))
         (completions (cmd-completions verb)))
    (when completions
      (setf *tab-complete-idx* (mod (1+ *tab-complete-idx*) (length completions)))
      ;; Replace just the verb with the completion (strip args from command template)
      (let* ((template (car (nth *tab-complete-idx* completions)))
             ;; Strip <arg> parts — keep just the bare command word
             (bare (first (uiop:split-string template :separator (list #\Space)))))
        (setf *input-text* (concatenate 'string bare " "))))))

;;; ---- Render: Unicode border above input line ----

(defparameter +char-height-cf+ 16)   ; local constant, avoids forward-ref to main

(defun render ()
  (when *show*
    (destructuring-bind (rw rh) (sdl:get-render-output-size *renderer*)
      (let* ((bar-h    18)
             (border-y (- rh bar-h +char-height-cf+))
             (input-y  (- rh bar-h))
             (cols     (max 2 (floor rw 8)))
             (hline    (box-hline (max 0 (- cols 2))))
             (border   (concatenate 'string (string *box-ml*) hline (string *box-mr*))))
        ;; Background
        (sdl:set-render-draw-color *renderer* '(#x12 #x12 #x1e #xff))
        (sdl:render-fill-rect *renderer* (list 0 border-y rw (+ +char-height-cf+ bar-h)))
        ;; ASCII top border
        (let ((tx (create-texture-from-text border)))
          (destructuring-bind (w h) (sdl:get-texture-size tx)
            (sdl:render-texture *renderer* tx nil
                                (list 0 (+ border-y (- +char-height-cf+ h)) w h)))
          (sdl:destroy-texture tx))
        ;; Autocomplete hint (greyed out, shown right of cursor)
        (let* ((parts (uiop:split-string *input-text* :separator (list #\Space)))
               (verb (first parts))
               (completions (cmd-completions verb))
               (hint (when (and completions (= (length parts) 1)
                               (> (length *input-text*) 1))
                       (let* ((tidx (if (>= *tab-complete-idx* 0)
                                        (mod *tab-complete-idx* (length completions)) 0))
                              (best (car (nth tidx completions))))
                         (when (> (length best) (length verb))
                           (subseq best (length verb)))))))
          (when hint
            (let* ((hint-x (+ 4 (* (length *input-text*) 8)))
                   (tx (create-texture-from-text-colored hint '(#x55 #x55 #x77 #xff))))
              (destructuring-bind (w h) (sdl:get-texture-size tx)
                (declare (ignore w))
                (sdl:render-texture *renderer* tx nil
                                    (list hint-x (+ input-y (floor (- bar-h h) 2))
                                          (* (length hint) 8) h)))
              (sdl:destroy-texture tx))))
        ;; Input text
        (let* ((display *input-text*)
               (tx (create-texture-from-text display)))
          (destructuring-bind (w h) (sdl:get-texture-size tx)
            (sdl:render-texture *renderer* tx nil
                                (list 4 (+ input-y (floor (- bar-h h) 2)) w h))
            (setf (cursor:midpoint *cursor*)
                  (list (+ 4 w) (+ input-y (floor bar-h 2)))))
          (sdl:destroy-texture tx))
        ;; Blinking cursor
        (cursor:render *cursor*)))))
(export 'render)

;;; ---- Path utilities ----

(defun resolve-path (arg base)
  "Resolve ARG relative to BASE directory. Handles absolute paths."
  (let ((trimmed (string-trim '(#\Space) arg)))
    (if (> (length trimmed) 0)
        (let ((p (pathname trimmed)))
          (if (or (uiop:absolute-pathname-p p)
                  (and (>= (length trimmed) 2) (char= (char trimmed 1) #\:)))
              trimmed
              (namestring (merge-pathnames p (pathname base)))))
        base)))

;;; ---- Command execution ----

(defun execute-command ()
  (setf *tab-complete-idx* -1)
  (let* ((raw  *input-text*)
         (cmd  (string-downcase (string-trim '(#\Space) raw)))
         (parts (uiop:split-string cmd :separator (list #\Space)))
         (verb  (first parts)))
    (cond

      ;; /quit
      ((string= cmd "/quit")
       (main:push-notification "Quit")
       (main:set-running nil) (reset))

      ;; /fps
      ((string= cmd "/fps")
       (setf main:*show-fps* (not main:*show-fps*))
       (main:push-notification (format nil "FPS: ~:[OFF~;ON~]" main:*show-fps*))
       (reset))

      ;; /font <path>
      ((string= verb "/font")
       (let ((path (string-trim '(#\Space) (subseq raw (length "/font")))))
         (if (and (> (length path) 0))
             (if (state:set-font path)
                 (main:push-notification (format nil "Font: ~a" (file-namestring path)))
                 (fmteo "Font not found: ~a~%" path))
             (fmteo "Usage: /font <path-to-ttf>~%")))
       (reset))

      ;; /open [path]  or  /e [path]
      ((or (string= verb "/open") (string= verb "/e"))
       (let ((path (string-trim '(#\Space)
                                (subseq raw (length verb)))))
         (if (> (length path) 0)
             (main:open-file (resolve-path path main:*cwd*))
             (main:open-file-browser)))
       (reset))

      ;; /w [path]  -- save
      ((string= verb "/w")
       (let ((path (string-trim '(#\Space) (subseq raw (length "/w")))))
         (main:save-file (if (> (length path) 0)
                             (resolve-path path main:*cwd*)
                             nil)))
       (reset))

      ;; /bind <mode> <key> <action>
      ((string= verb "/bind")
       (if (>= (length parts) 4)
           (let ((mode   (intern (string-upcase (second parts)) :keyword))
                 (kname  (third parts))
                 (action (intern (string-upcase (fourth parts)) :keyword)))
             (main:bind-key mode kname action)
             (main:push-notification (format nil "Bound ~a ~a -> ~a" mode kname action)))
           (fmteo "Usage: /bind <mode> <key> <action>~%"))
       (reset))

      ;; /notif  /notification
      ((or (string= cmd "/notif") (string= cmd "/notification"))
       (setf main:*notifications-enabled* (not main:*notifications-enabled*))
       (main:push-notification
        (format nil "Notifications: ~:[OFF~;ON~]" main:*notifications-enabled*))
       (reset))

      ;; /commands  /cmd  /cmds
      ((or (string= cmd "/commands") (string= cmd "/cmd") (string= cmd "/cmds"))
       (main:show-help) (reset))

      ;; /rename <new-name>
      ((string= verb "/rename")
       (let ((new-name (string-trim '(#\Space) (subseq raw (length "/rename")))))
         (if (and (> (length new-name) 0) main:*current-file*)
             (handler-case
                 (let* ((dir  (directory-namestring main:*current-file*))
                        (new-path (concatenate 'string dir new-name)))
                   (rename-file main:*current-file* new-path)
                   (setf main:*current-file* (namestring (truename new-path)))
                   (main:push-notification (format nil "Renamed: ~a" new-name)))
               (error (e) (fmteo "Rename failed: ~a~%" e)))
             (fmteo "Usage: /rename <new-name>  (file must be open)~%")))
       (reset))

      ;; /cd [path]  -- change working directory
      ((string= verb "/cd")
       (let* ((arg  (string-trim '(#\Space) (subseq raw (length "/cd"))))
              (path (if (> (length arg) 0)
                        (resolve-path arg main:*cwd*)
                        (namestring (truename (user-homedir-pathname))))))
         (let ((resolved (ignore-errors (truename path))))
           (if (and resolved (uiop:directory-pathname-p resolved))
               (progn
                 (setf main:*cwd* (namestring resolved))
                 (main:push-notification (format nil "cd: ~a" main:*cwd*)))
               (progn
                 ;; Maybe they typed a path without trailing slash — try as dir
                 (let ((resolved2 (ignore-errors
                                    (truename (make-pathname :defaults path :name nil :type nil)))))
                   (if resolved2
                       (progn (setf main:*cwd* (namestring resolved2))
                              (main:push-notification (format nil "cd: ~a" main:*cwd*)))
                       (fmteo "cd: not a directory: ~a~%" path)))))))
       (reset))

      ;; /ls [path]  /list [path]  -- open file browser at path
      ((or (string= verb "/ls") (string= verb "/list"))
       (let* ((arg  (string-trim '(#\Space) (subseq raw (length verb))))
              (path (if (> (length arg) 0)
                        (resolve-path arg main:*cwd*)
                        main:*cwd*)))
         (let ((resolved (ignore-errors (truename path))))
           (if resolved
               (main:open-file-browser (namestring resolved))
               (main:open-file-browser main:*cwd*))))
       (reset))

      ;; /pwd  -- print working directory
      ((string= cmd "/pwd")
       (main:push-notification (format nil "~a" main:*cwd*))
       (reset))

      ;; /mkdir <name>  -- create directory
      ((string= verb "/mkdir")
       (let ((name (string-trim '(#\Space) (subseq raw (length "/mkdir")))))
         (if (> (length name) 0)
             (let ((path (merge-pathnames
                          (make-pathname :directory (list :relative name))
                          (pathname main:*cwd*))))
               (handler-case
                   (progn
                     (ensure-directories-exist path)
                     (main:push-notification (format nil "mkdir: ~a" name)))
                 (error (e) (fmteo "mkdir failed: ~a~%" e))))
             (fmteo "Usage: /mkdir <name>~%")))
       (reset))

      ;; /touch <name>  -- create empty file
      ((string= verb "/touch")
       (let ((name (string-trim '(#\Space) (subseq raw (length "/touch")))))
         (if (> (length name) 0)
             (let ((path (merge-pathnames name (pathname main:*cwd*))))
               (handler-case
                   (progn
                     (unless (probe-file path)
                       (with-open-file (f path :direction :output
                                               :if-does-not-exist :create)
                         (declare (ignore f))))
                     (main:push-notification (format nil "touch: ~a" name)))
                 (error (e) (fmteo "touch failed: ~a~%" e))))
             (fmteo "Usage: /touch <name>~%")))
       (reset))

      ;; /rm <name>  -- delete file or empty directory
      ((string= verb "/rm")
       (let ((name (string-trim '(#\Space) (subseq raw (length "/rm")))))
         (if (> (length name) 0)
             (let ((path (merge-pathnames name (pathname main:*cwd*))))
               (handler-case
                   (cond
                     ((not (probe-file path))
                      (fmteo "rm: no such file: ~a~%" name))
                     ((uiop:directory-pathname-p (truename path))
                      (uiop:delete-directory-tree (truename path) :validate t)
                      (main:push-notification (format nil "rm dir: ~a" name)))
                     (t
                      (delete-file path)
                      (main:push-notification (format nil "rm: ~a" name))))
                 (error (e) (fmteo "rm failed: ~a~%" e))))
             (fmteo "Usage: /rm <name>~%")))
       (reset))

      ;; /cp <src> <dst>  -- copy a file
      ((string= verb "/cp")
       (if (>= (length parts) 3)
           (let* ((src-arg (second parts))
                  (dst-arg (third parts))
                  (src (resolve-path src-arg main:*cwd*))
                  (dst (resolve-path dst-arg main:*cwd*)))
             (handler-case
                 (progn
                   (uiop:copy-file src dst)
                   (main:push-notification (format nil "cp: ~a -> ~a" src-arg dst-arg)))
               (error (e) (fmteo "cp failed: ~a~%" e))))
           (fmteo "Usage: /cp <src> <dst>~%"))
       (reset))

      (t
       (fmteo "Unknown command: ~a~%" raw)
       (reset)))))

;;; ---- Key / text input ----

(defun handle-key (key)
  (cond
    ((= key (char-code #\Esc))    (reset))
    ((= key (char-code #\Return)) (execute-command))
    ((= key (char-code #\Tab))
     ;; Cycle tab completions
     (complete-tab))
    ((= key (char-code #\Backspace))
     (setf *tab-complete-idx* -1)
     (when (> (length *input-text*) 1)   ; keep the leading "/"
       (setf *input-text* (subseq *input-text* 0 (1- (length *input-text*))))))))
(export 'handle-key)

(defun handle-text (text)
  (when *show*
    (when *cmd-just-opened*
      (setf *cmd-just-opened* nil)
      (return-from handle-text))
    (setf *tab-complete-idx* -1)
    (setf *input-text* (concatenate 'string *input-text* text))))
(export 'handle-text)
