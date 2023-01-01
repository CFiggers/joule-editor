# Joule editor

A simple terminal-based text editor written in [Janet](janet-lang/janet). Inspired by (but not a full faithful recreation of) [this guide](https://viewsourcecode.org/snaptoken/kilo/index.html) by [paigeruten](https://github.com/paigeruten).

![joule-0 0 4-a-demo](https://user-images.githubusercontent.com/55862180/210149130-076b412a-f1ae-4b55-8507-ce3e9980d85a.gif)

## Features

Finished (at least mostly):
- [x] TUI text editing (file loading, editing, saving)
- [x] Lightweight executable
- [x] Mobile-friendly (e.g. in [Termux](https://termux.dev/en/) on Android)
- [x] Syntax highlighting (for supported languages)
- [x] Mouse support (clicking and scrolling)
- [x] Basic search

Planned:
- [ ] Unlimited undo/redo history
- [ ] Command palette
- [ ] Persistent configuration (via dotfile)
- [ ] Multiple files open at once
- [ ] Multi-cursor editing
- [ ] RegEx find and find + replace
- [ ] Plugin system

## Getting Started 

### Building from Source

Requires [Janet](https://www.github.com/janet-lang/janet) and [JPM](https://www.github.com/janet-lang/jpm). Not tested on Windows.

1. Clone this repo (for e.g., with the GitHub CLI, `$ gh repo clone CFiggers/joule-editor`.)

2. Change directories into the cloned repo: `$ cd joule-editor`

3. Fetch and install required dependencies: `$ jpm deps` (on Ubuntu and similar systems, may required elevated permissions, e.g. `$ sudo jpm deps`)

Now you can either build a native binary executable using `$ jpm build` or run the Janet source code directly using the `janet` command and passing in the `src/joule.janet` source file.

- To Build a Native Executable:
    - `$ jpm build`
    - `$ ./build/joule`
- Or to Run as a script using Janet:
    - `$ janet src/joule.janet`

## Usage

Joule is *not* a modal editor, meaning you can immediately start typing to make edits without needing to enter a specific editing mode (like vi and vim). 

### Keyboard Shortcuts

| Binding     | Action                          |
| ----------- | ------------------------------- |
| Ctrl + q    | Quit                            |
| Ctrl + l    | Load File                       |
| Ctrl + s    | Save                            |
| Ctrl + a    | Save As                         |
| Ctrl + f    | Find                            |
| Ctrl + g    | Go To Line                      |
| Ctrl + c    | Copy (to internal clipboard)    |
| Ctrl + x    | Cut (to internal clipboard)     |
| Ctrl + p    | Paste (from internal clipboard) |
| Ctrl + n    | Toggle Line Numbers             |
| Ctrl + w    | Close Current File              |
| Ctrl + d    | Open Debug REPL                 |
| Shift + Del | Delete current line             |

# Copyright

Copyright (c) 2022 Caleb Figgers