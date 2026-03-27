#include <SDL3/SDL.h>

const Uint32 SDL_INIT_AUDIO_ = SDL_INIT_AUDIO;
const Uint32 SDL_INIT_VIDEO_ = SDL_INIT_VIDEO;
const Uint32 SDL_INIT_JOYSTICK_ = SDL_INIT_JOYSTICK;
const Uint32 SDL_INIT_HAPTIC_ = SDL_INIT_HAPTIC;
const Uint32 SDL_INIT_GAMEPAD_ = SDL_INIT_GAMEPAD;
const Uint32 SDL_INIT_EVENTS_ = SDL_INIT_EVENTS;
const Uint32 SDL_INIT_SENSOR_ = SDL_INIT_SENSOR;
const Uint32 SDL_INIT_CAMERA_ = SDL_INIT_CAMERA;

const size_t SDL_EVENT_SIZE = sizeof(SDL_Event);
void sdl_frect_init(SDL_FRect *r, float x, float y, float w, float h) {
  r->x = x;
  r->y = y;
  r->w = w;
  r->h = h;
}
void sdl_color_init(SDL_Color *c, Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
  c->r = r;
  c->g = g;
  c->b = b;
  c->a = a;
}

const Uint32 SDL_EVENT_FIRST_ = SDL_EVENT_FIRST;
const Uint32 SDL_EVENT_QUIT_ = SDL_EVENT_QUIT;
const Uint32 SDL_EVENT_TERMINATING_ = SDL_EVENT_TERMINATING;
const Uint32 SDL_EVENT_LOW_MEMORY_ = SDL_EVENT_LOW_MEMORY;
const Uint32 SDL_EVENT_WINDOW_SHOWN_ = SDL_EVENT_WINDOW_SHOWN;
const Uint32 SDL_EVENT_WINDOW_HIDDEN_ = SDL_EVENT_WINDOW_HIDDEN;
const Uint32 SDL_EVENT_WINDOW_EXPOSED_ = SDL_EVENT_WINDOW_EXPOSED;
const Uint32 SDL_EVENT_WINDOW_MOVED_ = SDL_EVENT_WINDOW_MOVED;
const Uint32 SDL_EVENT_WINDOW_RESIZED_ = SDL_EVENT_WINDOW_RESIZED;
const Uint32 SDL_EVENT_WINDOW_MINIMIZED_ = SDL_EVENT_WINDOW_MINIMIZED;
const Uint32 SDL_EVENT_WINDOW_MAXIMIZED_ = SDL_EVENT_WINDOW_MAXIMIZED;
const Uint32 SDL_EVENT_WINDOW_RESTORED_ = SDL_EVENT_WINDOW_RESTORED;
const Uint32 SDL_EVENT_WINDOW_MOUSE_ENTER_ = SDL_EVENT_WINDOW_MOUSE_ENTER;
const Uint32 SDL_EVENT_WINDOW_MOUSE_LEAVE_ = SDL_EVENT_WINDOW_MOUSE_LEAVE;
const Uint32 SDL_EVENT_WINDOW_FOCUS_GAINED_ = SDL_EVENT_WINDOW_FOCUS_GAINED;
const Uint32 SDL_EVENT_WINDOW_FOCUS_LOST_ = SDL_EVENT_WINDOW_FOCUS_LOST;
const Uint32 SDL_EVENT_WINDOW_CLOSE_REQUESTED_ = SDL_EVENT_WINDOW_CLOSE_REQUESTED;
const Uint32 SDL_EVENT_KEY_DOWN_ = SDL_EVENT_KEY_DOWN;
const Uint32 SDL_EVENT_KEY_UP_ = SDL_EVENT_KEY_UP;
const Uint32 SDL_EVENT_TEXT_EDITING_ = SDL_EVENT_TEXT_EDITING;
const Uint32 SDL_EVENT_TEXT_INPUT_ = SDL_EVENT_TEXT_INPUT;
const Uint32 SDL_EVENT_MOUSE_MOTION_ = SDL_EVENT_MOUSE_MOTION;
const Uint32 SDL_EVENT_MOUSE_BUTTON_DOWN_ = SDL_EVENT_MOUSE_BUTTON_DOWN;
const Uint32 SDL_EVENT_MOUSE_BUTTON_UP_ = SDL_EVENT_MOUSE_BUTTON_UP;
const Uint32 SDL_EVENT_MOUSE_WHEEL_ = SDL_EVENT_MOUSE_WHEEL;
const Uint32 SDL_EVENT_DROP_FILE_ = SDL_EVENT_DROP_FILE;

/* Drop event accessor */
const char *sdl_drop_event_data(SDL_DropEvent *e) { return e->data; }

Uint32 sdl_keyboard_event_type(SDL_KeyboardEvent *e) { return e->type; }
Uint32 sdl_keyboard_event_scancode(SDL_KeyboardEvent *e) { return e->scancode; }
Uint32 sdl_keyboard_event_key(SDL_KeyboardEvent *e) { return e->key; }
Uint16 sdl_keyboard_event_mod(SDL_KeyboardEvent *e) { return e->mod; }
bool sdl_keyboard_event_down(SDL_KeyboardEvent *e) { return e->down; }
bool sdl_keyboard_event_repeat(SDL_KeyboardEvent *e) { return e->repeat; }

const char *sdl_text_input_event_text(SDL_TextInputEvent *e) { return e->text; }

/* Mouse button event accessors */
float sdl_mouse_button_event_x(SDL_MouseButtonEvent *e) { return e->x; }
float sdl_mouse_button_event_y(SDL_MouseButtonEvent *e) { return e->y; }
Uint8 sdl_mouse_button_event_button(SDL_MouseButtonEvent *e) { return e->button; }
Uint8 sdl_mouse_button_event_clicks(SDL_MouseButtonEvent *e) { return e->clicks; }
bool sdl_mouse_button_event_down(SDL_MouseButtonEvent *e) { return e->down; }

/* Mouse motion event accessors */
float sdl_mouse_motion_event_x(SDL_MouseMotionEvent *e) { return e->x; }
float sdl_mouse_motion_event_y(SDL_MouseMotionEvent *e) { return e->y; }
Uint32 sdl_mouse_motion_event_state(SDL_MouseMotionEvent *e) { return e->state; }

/* Mouse wheel event accessors */
float sdl_mouse_wheel_event_x(SDL_MouseWheelEvent *e) { return e->x; }
float sdl_mouse_wheel_event_y(SDL_MouseWheelEvent *e) { return e->y; }

const Uint64 SDL_WINDOW_FULLSCREEN_ = SDL_WINDOW_FULLSCREEN;
const Uint64 SDL_WINDOW_OPENGL_ = SDL_WINDOW_OPENGL;
const Uint64 SDL_WINDOW_OCCLUDED_ = SDL_WINDOW_OCCLUDED;
const Uint64 SDL_WINDOW_HIDDEN_ = SDL_WINDOW_HIDDEN;
const Uint64 SDL_WINDOW_BORDERLESS_ = SDL_WINDOW_BORDERLESS;
const Uint64 SDL_WINDOW_RESIZABLE_ = SDL_WINDOW_RESIZABLE;
const Uint64 SDL_WINDOW_MINIMIZED_ = SDL_WINDOW_MINIMIZED;
const Uint64 SDL_WINDOW_MAXIMIZED_ = SDL_WINDOW_MAXIMIZED;
const Uint64 SDL_WINDOW_MOUSE_GRABBED_ = SDL_WINDOW_MOUSE_GRABBED;
const Uint64 SDL_WINDOW_INPUT_FOCUS_ = SDL_WINDOW_INPUT_FOCUS;
const Uint64 SDL_WINDOW_MOUSE_FOCUS_ = SDL_WINDOW_MOUSE_FOCUS;
const Uint64 SDL_WINDOW_EXTERNAL_ = SDL_WINDOW_EXTERNAL;
const Uint64 SDL_WINDOW_MODAL_ = SDL_WINDOW_MODAL;
const Uint64 SDL_WINDOW_HIGH_PIXEL_DENSITY_ = SDL_WINDOW_HIGH_PIXEL_DENSITY;
const Uint64 SDL_WINDOW_MOUSE_CAPTURE_ = SDL_WINDOW_MOUSE_CAPTURE;
const Uint64 SDL_WINDOW_MOUSE_RELATIVE_MODE_ = SDL_WINDOW_MOUSE_RELATIVE_MODE;
const Uint64 SDL_WINDOW_ALWAYS_ON_TOP_ = SDL_WINDOW_ALWAYS_ON_TOP;
const Uint64 SDL_WINDOW_UTILITY_ = SDL_WINDOW_UTILITY;
const Uint64 SDL_WINDOW_TOOLTIP_ = SDL_WINDOW_TOOLTIP;
const Uint64 SDL_WINDOW_POPUP_MENU_ = SDL_WINDOW_POPUP_MENU;
const Uint64 SDL_WINDOW_KEYBOARD_GRABBED_ = SDL_WINDOW_KEYBOARD_GRABBED;
const Uint64 SDL_WINDOW_FILL_DOCUMENT_ = SDL_WINDOW_FILL_DOCUMENT;
const Uint64 SDL_WINDOW_VULKAN_ = SDL_WINDOW_VULKAN;
const Uint64 SDL_WINDOW_METAL_ = SDL_WINDOW_METAL;
const Uint64 SDL_WINDOW_TRANSPARENT_ = SDL_WINDOW_TRANSPARENT;
const Uint64 SDL_WINDOW_NOT_FOCUSABLE_ = SDL_WINDOW_NOT_FOCUSABLE;
