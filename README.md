# Joule editor

A simple terminal-based text editor written in [Janet](janet-lang/janet). Follows [this guide](https://viewsourcecode.org/snaptoken/kilo/index.html) by [paigeruten](https://github.com/paigeruten).

<img width="715" alt="image" src="https://user-images.githubusercontent.com/55862180/181847990-41ff351f-fb29-49fa-90ce-08d4afd6287a.png">


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
