# Change Log

## 0.0.5
  - New Features
    - Status message when user triggers unimplemented (but planned) keybindings
    - Syntax highlighting for C source files 
  - Bugfixes
    - 
  - Misc
    - Added test suite 1
    - Static linking of final executable

## 0.0.4-b
  - Bugfixes
    - Fix program freeze when pressing Esc key (caused by upstream dependency)

## 0.0.4-a
  - Bugfixes
    - Ctrl + C on program startup causes crash
    - Program startup with few terminal rows causes crash
    - Some keys (Home, End, PgUp, PgDn, Backspace, Delete, key combos w/ left and right arrows) don't reset x-position memory
    - Delete key not working
    - Resizing terminal window interpreted as space key

## 0.0.4
  - New Features
    - Mouse support (clicks and scrolling)
    - File type detection
  - Bug Fixes
    - Numerous

## 0.0.3-a
- Bugfixes
  - Minor glitch with search modal

## 0.0.3 (Aug 6, 2022)
  - New Features
    - Shift + Del to delete an entire row
    - Select text with Shift + Arrows (same line only for now)
    - Jump to row number (Ctrl + G)
    - Navigate by word with Ctrl + Arrows
    - Basic Clipboard functionality and Copy (Ctrl + C) / Cut (Ctrl + X) / Paste (Ctrl + P)
  - Bug Fixes
    - Glitches when exiting modals and return to cursor position
    - Bugs in confirm-lose-changes modal

## 0.0.2 (Aug 3, 2022)
  - New Features
    - Incremental highlight of search while typing
    - Debug Mode
  - Bug Fixes
    - Backspace handling in modals
    - Return to original position when cancelling search modal
    - Search skips first on-screen result

## 0.0.1 (Aug 3, 2022)
  - Initial release.