;;;; sdl.lisp -- CFFI bindings for SDL3 and SDL_ttf
;;;;
;;;; This module provides Common Lisp bindings for the SDL3 multimedia
;;;; library and SDL_ttf for font rendering. It uses CFFI to interface
;;;; with the underlying C libraries.

(defpackage :sdl
  (:use :cl))

(in-package :sdl)

;;; Helper Functions ;;;

(defun read-foreign-uint32 (name)
  "Read a Uint32 constant from a foreign symbol.
   NAME: The name of the symbol (without trailing underscore).
   Returns the unsigned 32-bit integer value."
  (let ((ptr (cffi:foreign-symbol-pointer name)))
    (unless ptr
      (format t "Warning: SDL symbol ~a not found; returning 0. Ensure SDL library is available.~%" name)
      0)
    (when ptr (cffi:mem-ref ptr :uint32))))

(defun read-foreign-uint64 (name)
  "Read a Uint64 constant from a foreign symbol.
   NAME: The name of the symbol (without trailing underscore).
   Returns the unsigned 64-bit integer value."
  (let ((ptr (cffi:foreign-symbol-pointer name)))
    (unless ptr
      (format t "Warning: SDL symbol ~a not found; returning 0. Ensure SDL library is available.~%" name)
      0)
    (when ptr (cffi:mem-ref ptr :uint64))))

(defun read-foreign-size (name)
  "Read a size_t constant from a foreign symbol.
   NAME: The name of the symbol.
   Returns the size value."
  (let ((ptr (cffi:foreign-symbol-pointer name)))
    (unless ptr
      (format t "Warning: SDL symbol ~a not found; returning 0. Ensure SDL library is available.~%" name)
      0)
    (when ptr (cffi:mem-ref ptr :size))))

;; Add Unix library path for 64-bit systems
(pushnew #p"/usr/local/lib64/" cffi:*foreign-library-directories*)

;; Add the project root (cwd) so SDL3.dll and libsdl-struct-accessors.so are found
(pushnew (uiop:getcwd) cffi:*foreign-library-directories*)

;;; Foreign Library Definitions ;;;

;; SDL3 core library
(cffi:define-foreign-library libsdl3
  (:darwin "libSDL3.dylib")
  (:unix   "libSDL3.so")
  (:windows "SDL3.dll")
  (t (:default "SDL3")))
(cffi:use-foreign-library libsdl3)

;; SDL3_ttf library for font rendering
(cffi:define-foreign-library libsdl3-ttf
  (:darwin "libSDL3_ttf.dylib")
  (:unix   "libSDL3_ttf.so")
  (:windows "SDL3_ttf.dll")
  (t (:default "SDL3_ttf")))
(cffi:use-foreign-library libsdl3-ttf)

;;; SDL Structures ;;;

;; SDL_Color structure (RGBA color components)
(cffi:defcstruct color (r :uint8) (g :uint8) (b :uint8) (a :uint8))

;; Initialize SDL_Color in pure Lisp
(defun %color-init (ptr r g b a)
  (setf (cffi:mem-ref ptr :uint8 0) r
        (cffi:mem-ref ptr :uint8 1) g
        (cffi:mem-ref ptr :uint8 2) b
        (cffi:mem-ref ptr :uint8 3) a))

;; Macro to create and initialize an SDL_Color
;; VAR: The variable name to bind
;; RGBA: Optional list of (r g b a) values (0-255)
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
  "Get the SDL_Color value from a pointer.
   PTR: Pointer to an SDL_Color struct.
   Returns the color as a CFFI struct."
  (cffi:mem-ref ptr '(:struct color)))
(export 'color-value)

;; SDL_FRect structure (floating-point rectangle)
(cffi:defcstruct frect (x :float) (y :float) (w :float) (h :float))

;; Initialize SDL_FRect in pure Lisp
(defun %frect-init (ptr x y w h)
  (setf (cffi:mem-ref ptr :float 0) (float x)
        (cffi:mem-ref ptr :float 4) (float y)
        (cffi:mem-ref ptr :float 8) (float w)
        (cffi:mem-ref ptr :float 12) (float h)))

;; Macro to create and initialize an SDL_FRect
;; VAR: The variable name to bind
;; XYWH: Optional list of (x y w h) values
(defmacro with-frect ((var xywh) &body body)
  `(if ,xywh
       (cffi:with-foreign-object (,var '(:struct frect))
         (destructuring-bind (x y w h) ,xywh
           (%frect-init ,var (float x) (float y) (float w) (float h)))
         ,@body)
       (let ((,var (cffi:null-pointer)))
         ,@body)))
(export 'with-frect)

;;; SDL Functions ;;;

;; Create an SDL texture from a surface
(cffi:defcfun ("SDL_CreateTextureFromSurface" create-texture-from-surface) :pointer
  (renderer :pointer) (surface :pointer))
(export 'create-texture-from-surface)

;; Window creation flags
(defparameter +window-flags+
  (list
   :fullscreen           #x00000001
   :opengl               #x00000002
   :occluded             #x00000004
   :hidden               #x00000008
   :borderless           #x00000010
   :resizable            #x00000020
   :minimized            #x00000040
   :maximized            #x00000080
   :mouse-grabbed        #x00000100
   :input-focus          #x00000200
   :mouse-focus          #x00000400
   :external             #x00000800
   :modal                #x00001000
   :high-pixel-density   #x00002000
   :mouse-capture        #x00004000
   :mouse-relative-mode  #x00008000
   :always-on-top        #x00010000
   :utility              #x00020000
   :tooltip              #x00040000
   :popup-menu           #x00080000
   :keyboard-grabbed     #x00100000
   :fill-document        #x00200000
   :vulkan               #x10000000
   :metal                #x20000000
   :transparent          #x40000000
   :not-focusable        #x80000000))

;; Create a window and associated renderer
(cffi:defcfun ("SDL_CreateWindowAndRenderer" %create-window-and-renderer) :bool
  (title :string) (w :int) (h :int) (window-flags :uint64) (window :pointer)
  (renderer :pointer))

(defun create-window-and-renderer (title width height flags)
  "Create an SDL window and renderer with the specified properties.
   TITLE: Window title string.
   WIDTH: Window width in pixels.
   HEIGHT: Window height in pixels.
   FLAGS: List of window flag keywords (e.g., :resizable).
   Returns three values: success boolean, window pointer, renderer pointer."
  (flet ((get-flag (kw)
           (or (getf +window-flags+ kw)
               (error "Unkown flag passed to CREATE-WINDOW-AND-RENDERER: ~a" kw))))
    (cffi:with-foreign-objects ((window :pointer) (renderer :pointer))
      (let ((success? (%create-window-and-renderer
                       title width height
                       (apply #'logior (mapcar #'get-flag flags))
                       window renderer)))
        (values
         success? (cffi:mem-ref window :pointer) (cffi:mem-ref renderer :pointer))))))
(export 'create-window-and-renderer)

;; Destroy a renderer
(cffi:defcfun ("SDL_DestroyRenderer" destroy-renderer) :void (renderer :pointer))
(export 'destroy-renderer)

;; Destroy a texture
(cffi:defcfun ("SDL_DestroyTexture" destroy-texture) :void (texture :pointer))
(export 'destroy-texture)

;; Destroy a window
(cffi:defcfun ("SDL_DestroyWindow" destroy-window) :void (window :pointer))
(export 'destroy-window)

;; Get the name of the current video driver
(cffi:defcfun ("SDL_GetCurrentVideoDriver" get-current-video-driver) :string)
(export 'get-current-video-driver)

;; Get the last SDL error string
(cffi:defcfun ("SDL_GetError" get-error) :string)
(export 'get-error)

;; Convert scancode to key code
(cffi:defcfun ("SDL_GetKeyFromScancode" get-key-from-scancode) :uint32
  (scancode :int) (modstate :uint16) (key-event :bool))
(export 'get-key-from-scancode)

;; Renderer logical presentation modes
(cffi:defcenum renderer-logical-presentation
  :disabled :stretch :letterbox :overscan :integer-scale)

;; Get renderer logical presentation
(cffi:defcfun ("SDL_GetRenderLogicalPresentation" get-render-logical-presentation) :bool
  (renderer :pointer) (w (:pointer :int)) (h (:pointer :int))
  (mode (:pointer renderer-logical-presentation)))

;; Get the render output size (actual drawing size)
(cffi:defcfun ("SDL_GetRenderOutputSize" %get-render-output-size) :bool
  (renderer :pointer) (w :pointer) (h :pointer))

(defun get-render-output-size (renderer)
  "Get the output size of the renderer.
   RENDERER: The SDL renderer pointer.
   Returns two values: (width height) list and success boolean."
  (cffi:with-foreign-objects ((w :int) (h :int))
    (let ((success? (%get-render-output-size renderer w h)))
      (values (list (cffi:mem-ref w :int) (cffi:mem-ref h :int)) success?))))
(export 'get-render-output-size)

;; Get the name of the renderer
(cffi:defcfun ("SDL_GetRendererName" get-renderer-name) :string (renderer :pointer))
(export 'get-renderer-name)

;; Get SDL library revision
(cffi:defcfun ("SDL_GetRevision" get-revision) :string)
(export 'get-revision)

;; Get texture size
(cffi:defcfun ("SDL_GetTextureSize" %get-texture-size) :bool
  (texture :pointer) (w :pointer) (h :pointer))

(defun get-texture-size (texture)
  "Get the size of a texture.
   TEXTURE: The SDL texture pointer.
   Returns two values: (width height) list and success boolean."
  (cffi:with-foreign-objects ((w :float) (h :float))
    (let ((success? (%get-texture-size texture w h)))
      (values (list (cffi:mem-ref w :float) (cffi:mem-ref h :float)) success?))))
(export 'get-texture-size)

;; Get elapsed time in milliseconds since SDL initialization
(cffi:defcfun ("SDL_GetTicks" get-ticks) :uint64)
(export 'get-ticks)

;; Get SDL library version
(cffi:defcfun ("SDL_GetVersion" get-version) :int)
(export 'get-version)

;; Get window size
(cffi:defcfun ("SDL_GetWindowSize" %get-window-size) :bool
  (window :pointer)
  (w (:pointer :int))
  (h (:pointer :int)))

(defun get-window-size (window)
  "Get the size of a window.
   WINDOW: The SDL window pointer.
   Returns two values: (width height) list and success boolean."
  (cffi:with-foreign-objects ((w :int) (h :int))
    (let ((success? (%get-window-size window w h)))
      (values (list (cffi:mem-ref w :int) (cffi:mem-ref h :int)) success?))))
(export 'get-window-size)

;; SDL initialization
(cffi:defcfun ("SDL_Init" %init) :bool (flags :uint32))

;; Initialization flags (SDL3 values)
(defparameter +init-flags+
  (list :audio    #x00000010
        :video    #x00000020
        :joystick #x00000200
        :haptic   #x00001000
        :gamepad  #x00002000
        :events   #x00004000
        :sensor   #x00008000
        :camera   #x00010000))

(defun init (flags)
  "Initialize SDL with the specified subsystems.
   FLAGS: List of initialization flag keywords (e.g., :video :events).
   Returns true if initialization succeeded."
  (flet ((get-flag (kw)
           (or (getf +init-flags+ kw)
               (error "Unkown flag passed to INIT: ~a" kw))))
    (let ((flags (apply #'logior (mapcar #'get-flag flags))))
      (%init flags))))
(export 'init)

;; Poll for the next event
(cffi:defcfun ("SDL_PollEvent" poll-event) :bool (event :pointer))
(export 'poll-event)

;; Shut down SDL
(cffi:defcfun ("SDL_Quit" quit) :void)
(export 'quit)

;; Clear the rendering target
(cffi:defcfun ("SDL_RenderClear" render-clear) :bool (renderer :pointer))
(export 'render-clear)

;; Fill a rectangle with the current draw color
(cffi:defcfun ("SDL_RenderFillRect" %render-fill-rect) :bool
  (renderer :pointer) (rect :pointer))

(defun render-fill-rect (renderer rect-vals)
  "Fill a rectangle with the current render draw color.
   RENDERER: The SDL renderer.
   RECT-VALS: List of (x y width height) values."
  (with-frect (rect rect-vals)
    (%render-fill-rect renderer rect)))
(export 'render-fill-rect)

;; Present the rendered frame to the screen
(cffi:defcfun ("SDL_RenderPresent" render-present) :bool (renderer :pointer))
(export 'render-present)

;; Draw a rectangle outline
(cffi:defcfun ("SDL_RenderRect" %render-rect) :bool (renderer :pointer) (rect :pointer))

(defun render-rect (renderer rect-vals)
  "Draw a rectangle outline with the current render draw color.
   RENDERER: The SDL renderer.
   RECT-VALS: List of (x y width height) values."
  (with-frect (rect rect-vals)
    (%render-rect renderer rect)))
(export 'render-rect)

;; Render a texture to the screen
(cffi:defcfun ("SDL_RenderTexture" %render-texture) :bool
  (renderer :pointer) (texture :pointer) (src-frect :pointer) (dst-frect :pointer))

(defun render-texture (renderer texture src-rect dst-rect)
  "Render a texture to the screen.
   RENDERER: The SDL renderer.
   TEXTURE: The texture to render.
   SRC-RECT: Source rectangle (nil for entire texture).
   DST-RECT: Destination rectangle on screen."
  (with-frect (src-frect src-rect)
    (with-frect (dst-frect dst-rect)
      (%render-texture renderer texture src-frect dst-frect))))
(export 'render-texture)

;; Set a hint/option
(cffi:defcfun ("SDL_SetHint" set-hint) :bool (name :string) (value :string))
(export 'set-hint)

;; Enable/disable vsync (1=on, 0=off)
(cffi:defcfun ("SDL_SetRenderVSync" set-render-vsync) :bool
  (renderer :pointer) (vsync :int))
(export 'set-render-vsync)

(cffi:defcfun ("SDL_SetWindowFullscreen" set-window-fullscreen) :bool
  (window :pointer) (fullscreen :bool))
(export 'set-window-fullscreen)

(cffi:defcfun ("SDL_SetWindowSize" set-window-size) :bool
  (window :pointer) (w :int) (h :int))
(export 'set-window-size)

(cffi:defcfun ("SDL_SetRenderDrawBlendMode" set-render-draw-blend-mode) :int
  (renderer :pointer) (blend-mode :int))
(export 'set-render-draw-blend-mode)

;; Set the render draw color
(cffi:defcfun ("SDL_SetRenderDrawColor" %set-render-draw-color) :bool
  (renderer :pointer) (r :uint8) (g :uint8) (b :uint8) (a :uint8))

(defun set-render-draw-color (renderer color-vals)
  "Set the color used for drawing operations.
   RENDERER: The SDL renderer.
   COLOR-VALS: List of (r g b a) values (0-255)."
  (destructuring-bind (r g b a) color-vals
    (%set-render-draw-color renderer r g b a)))
(export 'set-render-draw-color)

;; Set renderer logical presentation
(cffi:defcfun ("SDL_SetRenderLogicalPresentation" set-render-logical-presentation) :bool
  (renderer :pointer) (w :int) (h :int) (mode renderer-logical-presentation))
(export 'set-render-logical-presentation)

;; SDL event size (in bytes) - SDL3 uses 128-byte events
(defparameter +event-size+ 128)
(export '+event-size+)

;; SDL event type constants
(defparameter +event-types+
  (list :first                  #x100
        :quit                   #x100
        :terminating            #x101
        :low-memory             #x102
        :window-shown           #x202
        :window-hidden          #x203
        :window-exposed         #x204
        :window-moved           #x205
        :window-resized         #x206
        :window-minimized       #x207
        :window-maximized       #x208
        :window-restored        #x209
        :window-mouse-enter     #x210
        :window-mouse-leave     #x211
        :window-focus-gained    #x212
        :window-focus-lost      #x213
        :window-close-requested #x214
        :key-down               #x300
        :key-up                 #x301
        :text-editing           #x302
        :text-input             #x303
        :mouse-motion           #x400
        :mouse-button-down      #x401
        :mouse-button-up        #x402
        :mouse-wheel            #x403
        :drop-file              #x1000))
(export '+event-types+)

(defun event-type (event)
  "Get the event type from an SDL event pointer.
   EVENT: Pointer to an SDL event structure.
   Returns the event type keyword (e.g., :key-down, :quit)."
  (let ((raw (cffi:mem-ref event :uint32)))
    (loop for (key val) on +event-types+ by #'cddr
          when (= raw val) return key)))
(export 'event-type)

;;; Keyboard Event Accessors ;;;
;; Pure CFFI memory access - no C library needed
;; SDL3 struct offsets (verified from SDL_events.h)

(defun keyboard-event-type (e) (cffi:mem-ref e :uint32 0))
(export 'keyboard-event-type)

(defun keyboard-event-scancode (e) (cffi:mem-ref e :uint32 24))
(export 'keyboard-event-scancode)

(defun keyboard-event-key (e) (cffi:mem-ref e :uint32 28))
(export 'keyboard-event-key)

(defun keyboard-event-mod (e) (cffi:mem-ref e :uint16 32))
(export 'keyboard-event-mod)

(defun keyboard-event-down (e) (cffi:mem-ref e :bool 36))
(export 'keyboard-event-down)

(defun keyboard-event-repeat (e) (cffi:mem-ref e :bool 37))
(export 'keyboard-event-repeat)

;; Text input event accessor
;; SDL_TextInputEvent: type(0) reserved(4) timestamp(8) windowID(16) [pad4] text*(24)
(defun text-input-event-text (e)
  (let ((ptr (cffi:mem-ref e :pointer 24)))
    (when (and ptr (not (cffi:null-pointer-p ptr)))
      (cffi:foreign-string-to-lisp ptr))))
(export 'text-input-event-text)

;;; Mouse Button Event Accessors ;;;
;; SDL_MouseButtonEvent: type(0) reserved(4) timestamp(8) windowID(16) which(20)
;;   button(24) down(25) clicks(26) padding(27) x(28) y(32)

(defun mouse-button-event-x (e) (cffi:mem-ref e :float 28))
(export 'mouse-button-event-x)

(defun mouse-button-event-y (e) (cffi:mem-ref e :float 32))
(export 'mouse-button-event-y)

(defun mouse-button-event-button (e) (cffi:mem-ref e :uint8 24))
(export 'mouse-button-event-button)

(defun mouse-button-event-clicks (e) (cffi:mem-ref e :uint8 26))
(export 'mouse-button-event-clicks)

(defun mouse-button-event-down (e) (cffi:mem-ref e :bool 25))
(export 'mouse-button-event-down)

;;; Mouse Motion Event Accessors ;;;
;; SDL_MouseMotionEvent: type(0) reserved(4) timestamp(8) windowID(16) which(20)
;;   state(24) x(28) y(32) xrel(36) yrel(40)

(defun mouse-motion-event-x (e) (cffi:mem-ref e :float 28))
(export 'mouse-motion-event-x)

(defun mouse-motion-event-y (e) (cffi:mem-ref e :float 32))
(export 'mouse-motion-event-y)

(defun mouse-motion-event-state (e) (cffi:mem-ref e :uint32 24))
(export 'mouse-motion-event-state)

;;; Mouse Wheel Event Accessors ;;;
;; SDL_MouseWheelEvent: type(0) reserved(4) timestamp(8) windowID(16) which(20)
;;   x(24) y(28) direction(32) mouse_x(36) mouse_y(40)

(defun mouse-wheel-event-x (e) (cffi:mem-ref e :float 24))
(export 'mouse-wheel-event-x)

(defun mouse-wheel-event-y (e) (cffi:mem-ref e :float 28))
(export 'mouse-wheel-event-y)

;;; Drop Event Accessors ;;;
;; SDL_DropEvent: type(0) reserved(4) timestamp(8) windowID(16) x(20) y(24)
;;   [pad4 to align ptr] source*(32) data*(40)

(defun drop-event-data (e)
  (let ((ptr (cffi:mem-ref e :pointer 40)))
    (when (and ptr (not (cffi:null-pointer-p ptr)))
      (cffi:foreign-string-to-lisp ptr))))
(export 'drop-event-data)

;;; Modifier key bitmask helpers (SDL_Keymod values) ;;;
;; SDL_KMOD_SHIFT = 0x0003, SDL_KMOD_CTRL = 0x00C0, SDL_KMOD_ALT = 0x0300
(defun mod-shift-p (mod) (not (zerop (logand mod #x0003))))
(export 'mod-shift-p)

(defun mod-ctrl-p (mod) (not (zerop (logand mod #x00C0))))
(export 'mod-ctrl-p)

(defun mod-alt-p (mod) (not (zerop (logand mod #x0300))))
(export 'mod-alt-p)

;; Start/Stop text input (SDL3 requires window pointer)
(cffi:defcfun ("SDL_StartTextInput" start-text-input) :bool (window :pointer))
(export 'start-text-input)

(cffi:defcfun ("SDL_StopTextInput" stop-text-input) :bool (window :pointer))
(export 'stop-text-input)

;;; SDL_ttf Functions ;;;

;; Initialize SDL_ttf
(cffi:defcfun ("TTF_Init" ttf-init) :bool)
(export 'ttf-init)

;; Open a font file
(cffi:defcfun ("TTF_OpenFont" ttf-open-font) :pointer (file :string) (ptsize :float))
(export 'ttf-open-font)

;; Close a font
(cffi:defcfun ("TTF_CloseFont" ttf-close-font) :void (font :pointer))
(export 'ttf-close-font)

;; Shut down SDL_ttf
(cffi:defcfun ("TTF_Quit" ttf-quit) :void)
(export 'ttf-quit)

;; Render text with blended colors
(cffi:defcfun ("TTF_RenderText_Blended" %ttf-render-text-blended) :pointer
  (font :pointer) (text :string) (length :size) (fg (:struct color)))

(defun ttf-render-text-blended (font text fg-color)
  "Render text to a surface with blended colors.
   FONT: The SDL_ttf font pointer.
   TEXT: The string to render.
   FG-COLOR: List of (r g b a) color values.
   Returns a pointer to the rendered surface."
  (with-color (fgc fg-color)
    (%ttf-render-text-blended font text (length text) (color-value fgc))))
(export 'ttf-render-text-blended)

;; Get SDL_ttf library version
(cffi:defcfun ("TTF_Version" ttf-version) :int)
(export 'ttf-version)
