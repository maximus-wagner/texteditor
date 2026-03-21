(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :sdl)
    (defpackage :sdl
      (:use :cl)
      )))
(in-package :sdl)

(defun read-foreign-uint32 (name)
  (cffi:mem-ref (cffi:foreign-symbol-pointer name) :uint32))

(defun read-foreign-uint64 (name)
  (cffi:mem-ref (cffi:foreign-symbol-pointer name) :uint64))

(defun read-foreign-size (name)
  (cffi:mem-ref (cffi:foreign-symbol-pointer name) :size))

(cffi:define-foreign-library libsdl3
  (:darwin "libSDL3.dylib")
  (:unix   "libSDL3.so")
  (:windows "SDL3.dll")
  (t (:default "libSDL3")))
(cffi:use-foreign-library libsdl3)

(cffi:load-foreign-library
 (merge-pathnames #p"libsdl-struct-accessors.so" (uiop:getcwd)))

;;
;; Structures
;;

(cffi:defcstruct color (r :uint8) (g :uint8) (b :uint8) (a :uint8))

(cffi:defcfun ("sdl_color_init" %color-init) :void
  (c :pointer) (r :uint8) (g :uint8) (b :uint8) (a :uint8))

(defmacro with-color ((var rgba) &body body)
  `(if ,rgba
       (cffi:with-foreign-object (,var '(:struct color))
         (destructuring-bind (r g b a) ,rgba
           (%color-init ,var r g b a))
         ,@body)
       (let ((,var (cffi:null-pointer)))
         ,@body)))
(export 'with-color)
(defun color-value (ptr)
  (cffi:mem-ref ptr '(:struct color)))
(export 'color-value)

(cffi:defcstruct frect (x :float) (y :float) (w :float) (h :float))

(cffi:defcfun ("sdl_frect_init" %frect-init) :void
  (frect :pointer) (x :float) (y :float) (w :float) (h :float))

(defmacro with-frect ((var xywh) &body body)
  `(if ,xywh
       (cffi:with-foreign-object (,var '(:struct frect))
         (destructuring-bind (x y w h) ,xywh
           (%frect-init ,var (float x) (float y) (float w) (float h)))
         ,@body)
       (let ((,var (cffi:null-pointer)))
         ,@body)))
(export 'with-frect)

;;
;; Functions
;;

(cffi:defcfun ("SDL_CreateTextureFromSurface" create-texture-from-surface) :pointer
  (renderer :pointer) (surface :pointer))
(export 'create-texture-from-surface)

(defparameter +window-flags+
  (list
   :fullscreen (read-foreign-uint64 "SDL_WINDOW_FULLSCREEN_")
   :opengl (read-foreign-uint64 "SDL_WINDOW_OPENGL_")
   :occluded (read-foreign-uint64 "SDL_WINDOW_OCCLUDED_")
   :hidden (read-foreign-uint64 "SDL_WINDOW_HIDDEN_")
   :borderless (read-foreign-uint64 "SDL_WINDOW_BORDERLESS_")
   :resizable (read-foreign-uint64 "SDL_WINDOW_RESIZABLE_")
   :minimized (read-foreign-uint64 "SDL_WINDOW_MINIMIZED_")
   :maximized (read-foreign-uint64 "SDL_WINDOW_MAXIMIZED_")
   :mouse-grabbed (read-foreign-uint64 "SDL_WINDOW_MOUSE_GRABBED_")
   :input-focus (read-foreign-uint64 "SDL_WINDOW_INPUT_FOCUS_")
   :mouse-focus (read-foreign-uint64 "SDL_WINDOW_MOUSE_FOCUS_")
   :external (read-foreign-uint64 "SDL_WINDOW_EXTERNAL_")
   :modal (read-foreign-uint64 "SDL_WINDOW_MODAL_")
   :high-pixel-density (read-foreign-uint64 "SDL_WINDOW_HIGH_PIXEL_DENSITY_")
   :mouse-capture (read-foreign-uint64 "SDL_WINDOW_MOUSE_CAPTURE_")
   :mouse-relative-mode (read-foreign-uint64 "SDL_WINDOW_MOUSE_RELATIVE_MODE_")
   :always-on-top (read-foreign-uint64 "SDL_WINDOW_ALWAYS_ON_TOP_")
   :utility (read-foreign-uint64 "SDL_WINDOW_UTILITY_")
   :tooltip (read-foreign-uint64 "SDL_WINDOW_TOOLTIP_")
   :popup-menu (read-foreign-uint64 "SDL_WINDOW_POPUP_MENU_")
   :keyboard-grabbed (read-foreign-uint64 "SDL_WINDOW_KEYBOARD_GRABBED_")
   :fill-document (read-foreign-uint64 "SDL_WINDOW_FILL_DOCUMENT_")
   :vulkan (read-foreign-uint64 "SDL_WINDOW_VULKAN_")
   :metal (read-foreign-uint64 "SDL_WINDOW_METAL_")
   :transparent (read-foreign-uint64 "SDL_WINDOW_TRANSPARENT_")
   :not-focusable (read-foreign-uint64 "SDL_WINDOW_NOT_FOCUSABLE_")))
(cffi:defcfun ("SDL_CreateWindowAndRenderer" %create-window-and-renderer) :bool
  (title :string) (w :int) (h :int) (window-flags :uint64) (window :pointer)
  (renderer :pointer))
(defun create-window-and-renderer (title width height flags)
  (flet ((get-flag (kw)
           (or (getf +window-flags+ kw)
               (error "Unkown flag passed to CREATE-WINDOW-AND-RENDERER: ~a" kw))))
    (cffi:with-foreign-objects ((window :pointer) (renderer :pointer))
      (let ((success? (%create-window-and-renderer
                       title width height
                       (apply #'logior (mapcar #'get-flag flags))
                       window renderer)))
        (values (list (cffi:mem-ref window :pointer)
                      (cffi:mem-ref renderer :pointer))
                success?)))))
(export 'create-window-and-renderer)

(cffi:defcfun ("SDL_DestroyRenderer" destroy-renderer) :void (renderer :pointer))
(export 'destroy-renderer)

(cffi:defcfun ("SDL_DestroyTexture" destroy-texture) :void (texture :pointer))
(export 'destroy-texture)

(cffi:defcfun ("SDL_DestroyWindow" destroy-window) :void (window :pointer))
(export 'destroy-window)

(cffi:defcfun ("SDL_GetCurrentVideoDriver" get-current-video-driver) :string)
(export 'get-current-video-driver)

(cffi:defcfun ("SDL_GetError" get-error) :string)
(export 'get-error)

(cffi:defcenum renderer-logical-presentation
  :disabled :stretch :letterbox :overscan :integer-scale)
(cffi:defcfun ("SDL_GetRenderLogicalPresentation" get-render-logical-presentation) :bool
  (renderer :pointer) (w (:pointer :int)) (h (:pointer :int))
  (mode (:pointer renderer-logical-presentation)))

(cffi:defcfun ("SDL_GetRenderOutputSize" %get-render-output-size) :bool
  (renderer :pointer) (w :pointer) (h :pointer))
(defun get-render-output-size (renderer)
  (cffi:with-foreign-objects ((w :int) (h :int))
    (let ((success? (%get-render-output-size renderer w h)))
      (values (list (cffi:mem-ref w :int) (cffi:mem-ref h :int)) success?))))
(export 'get-render-output-size)

(cffi:defcfun ("SDL_GetRendererName" get-renderer-name) :string (renderer :pointer))
(export 'get-renderer-name)

(cffi:defcfun ("SDL_GetRevision" get-revision) :string)
(export 'get-revision)

(cffi:defcfun ("SDL_GetTextureSize" %get-texture-size) :bool
  (texture :pointer) (w :pointer) (h :pointer))
(defun get-texture-size (texture)
  (cffi:with-foreign-objects ((w :float) (h :float))
    (let ((success? (%get-texture-size texture w h)))
      (values (list (cffi:mem-ref w :float) (cffi:mem-ref h :float)) success?))))
(export 'get-texture-size)

(cffi:defcfun ("SDL_GetTicks" get-ticks) :uint64)
(export 'get-ticks)

(cffi:defcfun ("SDL_GetVersion" get-version) :int)
(export 'get-version)

(cffi:defcfun ("SDL_GetWindowSize" %get-window-size) :bool
  (window :pointer)
  (w (:pointer :int))
  (h (:pointer :int)))
(defun get-window-size (window)
  (cffi:with-foreign-objects ((w :int) (h :int))
    (let ((success? (%get-window-size window w h)))
      (values (list (cffi:mem-ref w :int) (cffi:mem-ref h :int)) success?))))
(export 'get-window-size)

(cffi:defcfun ("SDL_Init" %init) :bool (flags :uint32))
(defparameter +init-flags+
  (list :audio (read-foreign-uint32 "SDL_INIT_AUDIO_")
        :video (read-foreign-uint32 "SDL_INIT_VIDEO_")
        :joystick (read-foreign-uint32 "SDL_INIT_JOYSTICK_")
        :haptic (read-foreign-uint32 "SDL_INIT_HAPTIC_")
        :gamepad (read-foreign-uint32 "SDL_INIT_GAMEPAD_")
        :events (read-foreign-uint32 "SDL_INIT_EVENTS_")
        :sensor (read-foreign-uint32 "SDL_INIT_SENSOR_")
        :camera (read-foreign-uint32 "SDL_INIT_CAMERA_")))
(defun init (flags)
  (flet ((get-flag (kw)
           (or (getf +init-flags+ kw)
               (error "Unkown flag passed to INIT: ~a" kw))))
    (let ((flags (apply #'logior (mapcar #'get-flag flags))))
      (%init flags))))
(export 'init)

(cffi:defcfun ("SDL_PollEvent" poll-event) :bool (event :pointer))
(export 'poll-event)

(cffi:defcfun ("SDL_Quit" quit) :void)
(export 'quit)

(cffi:defcfun ("SDL_RenderClear" render-clear) :bool (renderer :pointer))
(export 'render-clear)

(cffi:defcfun ("SDL_RenderPresent" render-present) :bool (renderer :pointer))
(export 'render-present)

(cffi:defcfun ("SDL_RenderTexture" %render-texture) :bool
  (renderer :pointer) (texture :pointer) (src-frect :pointer) (dst-frect :pointer))
(defun render-texture (renderer texture src-rect dst-rect)
  (with-frect (src-frect src-rect)
    (with-frect (dst-frect dst-rect)
      (%render-texture renderer texture src-frect dst-frect))))
(export 'render-texture)

(cffi:defcfun ("SDL_SetHint" set-hint) :bool (name :string) (value :string))
(export 'set-hint)

(cffi:defcfun ("SDL_SetRenderLogicalPresentation" set-render-logical-presentation) :bool
  (renderer :pointer) (w :int) (h :int) (mode renderer-logical-presentation))
(export 'set-render-logical-presentation)

(defparameter +event-size+
  (read-foreign-size "SDL_EVENT_SIZE"))
(export '+event-size+)

(defparameter +event-types+
  (list :first (read-foreign-uint32 "SDL_EVENT_FIRST_")
        :quit (read-foreign-uint32 "SDL_EVENT_QUIT_")
        :terminating (read-foreign-uint32 "SDL_EVENT_TERMINATING_")
        :low-memory (read-foreign-uint32 "SDL_EVENT_LOW_MEMORY_")
        :window-shown (read-foreign-uint32 "SDL_EVENT_WINDOW_SHOWN_")
        :window-hidden (read-foreign-uint32 "SDL_EVENT_WINDOW_HIDDEN_")
        :window-exposed (read-foreign-uint32 "SDL_EVENT_WINDOW_EXPOSED_")
        :window-moved (read-foreign-uint32 "SDL_EVENT_WINDOW_MOVED_")
        :window-resized (read-foreign-uint32 "SDL_EVENT_WINDOW_RESIZED_")
        :window-minimized (read-foreign-uint32 "SDL_EVENT_WINDOW_MINIMIZED_")
        :window-maximized (read-foreign-uint32 "SDL_EVENT_WINDOW_MAXIMIZED_")
        :window-restored (read-foreign-uint32 "SDL_EVENT_WINDOW_RESTORED_")
        :window-mouse-enter (read-foreign-uint32 "SDL_EVENT_WINDOW_MOUSE_ENTER_")
        :window-mouse-leave (read-foreign-uint32 "SDL_EVENT_WINDOW_MOUSE_LEAVE_")
        :window-focus-gained (read-foreign-uint32 "SDL_EVENT_WINDOW_FOCUS_GAINED_")
        :window-focus-lost (read-foreign-uint32 "SDL_EVENT_WINDOW_FOCUS_LOST_")
        :window-close-requested (read-foreign-uint32 "SDL_EVENT_WINDOW_CLOSE_REQUESTED_")
        :key-down (read-foreign-uint32 "SDL_EVENT_KEY_DOWN_")
        :key-up (read-foreign-uint32 "SDL_EVENT_KEY_UP_")
        :mouse-motion (read-foreign-uint32 "SDL_EVENT_MOUSE_MOTION_")
        :mouse-button-down (read-foreign-uint32 "SDL_EVENT_MOUSE_BUTTON_DOWN_")
        :mouse-button-up (read-foreign-uint32 "SDL_EVENT_MOUSE_BUTTON_UP_")
        :mouse-wheel (read-foreign-uint32 "SDL_EVENT_MOUSE_WHEEL_")))
(export '+event-types+)

(defun event-type (event)
  (let ((raw (cffi:mem-ref event :uint32)))
    (loop for (key val) on +event-types+ by #'cddr
          when (= raw val) return key)))
(export 'event-type)

(cffi:defcfun ("sdl_keyboard_event_type" keyboard-event-type) :uint32 (e :pointer))
(export 'keyboard-event-type)
(cffi:defcfun ("sdl_keyboard_event_scancode" keyboard-event-scancode) :uint32
  (e :pointer))
(export 'keyboard-event-scancode)
(cffi:defcfun ("sdl_keyboard_event_key" keyboard-event-key) :uint32 (e :pointer))
(export 'keyboard-event-key)
(cffi:defcfun ("sdl_keyboard_event_mod" keyboard-event-mod) :uint16 (e :pointer))
(export 'keyboard-event-mod)
(cffi:defcfun ("sdl_keyboard_event_down" keyboard-event-down) :bool (e :pointer))
(export 'keyboard-event-down)
(cffi:defcfun ("sdl_keyboard_event_repeat" keyboard-event-repeat) :bool (e :pointer))
(export 'keyboard-event-repeat)
