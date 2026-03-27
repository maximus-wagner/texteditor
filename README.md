# Text Editor

A lightweight text editor written in Common Lisp, powered by SDL3 for rendering and input handling. Features vim-like modal editing and a command frame.

## Prerequisites

- [SBCL](http://www.sbcl.org/) (Steel Bank Common Lisp)
- [Quicklisp](https://www.quicklisp.org/) (bundled via `quicklisp.lisp` if not installed)
- SDL3 (v3.4.2) and SDL3_ttf (v3.2.2) runtime libraries (vendored for Windows)

The editor will automatically find a suitable monospace font on your system (Consolas, DejaVu Sans Mono, Liberation Mono, Menlo, or Courier New). A retro IBM VGA-style font (`assets/Px437_ATI_8x16.ttf`) is bundled in the repo for those who want it.

## Running

**Windows:**
```
run.bat
```

**Linux / macOS:**
```bash
chmod +x run.sh
./run.sh
```

Or manually via SBCL:
```
sbcl --non-interactive --load src/deps.lisp --load src/main.lisp --eval "(main:main)"
```

## Key Bindings

### Normal Mode

| Key | Action |
|-----|--------|
| `h` / Left Arrow | Move cursor left |
| `l` / Right Arrow | Move cursor right |
| `k` / Up Arrow | Move cursor up |
| `j` / Down Arrow | Move cursor down |
| `w` | Jump to next word end |
| `b` | Jump to previous word start |
| `0` | Go to beginning of line |
| `$` | Go to end of line |
| `Home` | Go to beginning of line |
| `End` | Go to end of line |
| Page Up/Down | Scroll 10 lines |
| `i` | Enter insert mode at cursor |
| `a` | Enter insert mode after cursor |
| `I` | Enter insert mode at line start |
| `A` | Enter insert mode at line end |
| `o` | Open line below and enter insert mode |
| `O` | Open line above and enter insert mode |
| `v` | Enter visual mode |
| `x` | Delete character under cursor |
| `d` | Delete line (or selection in visual mode) |
| `y` | Yank (copy) line |
| `p` | Paste |
| `Insert` | Open command frame |
| `Esc` | Clear visual selection |
| `F1` | Quit editor |

### Insert Mode

| Key | Action |
|-----|--------|
| Any printable ASCII | Insert character at cursor |
| Return | Insert newline |
| Backspace | Delete character before cursor |
| Delete | Delete character at cursor |
| Arrow keys | Move cursor (with shift for selection) |
| Home / End | Go to line start / end |
| Page Up/Down | Scroll 10 lines |
| `Esc` | Return to normal mode |

### Visual Mode

| Key | Action |
|-----|--------|
| `h` / `l` / `k` / `j` / Arrow keys | Extend selection |
| `w` | Extend selection to next word end |
| `b` | Extend selection to previous word start |
| `d` / `x` | Delete selection |
| `y` | Yank (copy) selection |
| `p` | Replace selection with clipboard |
| `Esc` | Clear selection and return to normal mode |

### Command Frame (open with `Insert`)

The command frame opens at the bottom of the screen with `/` pre-populated.

| Command | Description |
|---------|-------------|
| `/font <path>` | Set font to any `.ttf` file on your system |
| `/fps` | Toggle FPS counter |
| `/quit` | Exit editor |
| `Esc` | Close command frame |

### Setting a Custom Font

Use the `/font` command to load any TrueType font at runtime:

```
/font C:/Windows/Fonts/consola.ttf
/font /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
```

## Project Structure

```
assets/
  Px437_ATI_8x16.ttf     Bundled retro IBM VGA font (optional)
src/
  main.lisp              Entry point and monolithic editor logic
  deps.lisp              Quicklisp and CFFI dependency loader
  sdl.lisp               SDL3 and SDL3_ttf CFFI bindings
  state.lisp             Global state (renderer, font)
  cursor.lisp            Blinking cursor component
  utils.lisp             Helper functions (format, text-to-texture)
  command-frame.lisp     Command line interface
  entry.lisp             Modular entry point (experimental)
  struct-accessors.c     C helper for SDL3 struct accessors
  core/                  Core subsystem (sdl bindings, state, utils)
  ui/                    UI components (cursor, command frame)
  renderer/              Frame rendering pipeline
  events/                Event polling and dispatch
```

## Architecture

The editor is built around an SDL3 event loop with vim-like modal editing (normal, insert, visual modes):

1. **Events** (`src/events/`) -- Polls and dispatches SDL events (keyboard, text input, quit)
2. **UI** (`src/ui/`) -- Handles key input, manages the command frame and cursor
3. **Renderer** (`src/renderer/`) -- Clears the screen, renders text and UI, presents frames
4. **Core** (`src/core/`) -- SDL3 bindings, global state, and utility functions

The project is in transition from a monolithic architecture (`src/main.lisp`) to a modular one (`src/core/`, `src/ui/`, `src/renderer/`, `src/events/`). The run scripts currently use the monolithic entry point.

## Building the C Helper

The SDL3 struct accessor helper needs to be compiled:

```bash
gcc -shared -o libsdl-struct-accessors.so src/struct-accessors.c $(pkg-config --cflags --libs sdl3)
```
