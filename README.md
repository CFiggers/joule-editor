# Joule editor

A simple terminal-based text editor written in [Janet](janet-lang/janet). Inspired by (but not a full faithful recreation of) [this guide](https://viewsourcecode.org/snaptoken/kilo/index.html) by [paigeruten](https://github.com/paigeruten).

<img width="715" alt="image" src="https://user-images.githubusercontent.com/55862180/182267797-b7055f8a-b51c-4d9e-adac-615feb1392ba.png">

<img width="715" alt="image" src="https://user-images.githubusercontent.com/55862180/182267770-03603970-8142-4f7d-922f-b12b040e3533.png">

## Getting Started 

Requires [Janet](https://www.github.com/janet-lang/janet) and [JPM](https://www.github.com/janet-lang/jpm).

1. Clone this repo (for e.g., with the GitHub CLI, `$ gh repo clone CFiggers/joule-editor`.)

2. Change directories into the cloned repo: `$ cd joule-editor`

3. Fetch and install required dependencies: `$ jpm deps` (on Ubuntu and similar systems, may required elevated permissions, e.g. `$ sudo jpm deps`)

Now you can either build a native binary executable using `$ jpm build` or run the Janet source code directly using the `janet` command and passing in the `src/joule.janet` source file.

- Build a Native Executable
    - `$ jpm build`
    - `$ ./build/joule`
- Run using Janet
    - `$ janet src/joule.janet`
