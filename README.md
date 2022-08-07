# Joule editor

A simple terminal-based text editor written in [Janet](janet-lang/janet). Inspired by (but not a full faithful recreation of) [this guide](https://viewsourcecode.org/snaptoken/kilo/index.html) by [paigeruten](https://github.com/paigeruten).

![joule-0 0 3-a-demo](https://user-images.githubusercontent.com/55862180/183272658-b0c13977-35f1-42b2-a00e-c17eab1b8cdc.gif)

## Getting Started 

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
