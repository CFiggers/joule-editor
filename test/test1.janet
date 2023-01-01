(use judge)

(import "/src/joule")

### Testing Utilities ###

(defn ignore-screen-size []
  (set (joule/editor-state :screenrows) nil)
  (set (joule/editor-state :screencols) nil))

### Basic Functionality ###

(test editor-state-created
      # editor-state map exists
      (expect (truthy? joule/editor-state) true))

(test editor-state-reset
      #editor-state is default on-open state
      (joule/reset-editor-state)
      (ignore-screen-size)
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test editor-process-keystrokes
      (joule/reset-editor-state)
      (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
                 ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
                 ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter
                 97 98 99 :enter 49 50 51 :uparrow :backspace :home :end :home :delete :downarrow :rightarrow :rightarrow :leftarrow
                 :pageup :pagedown]
            (joule/editor-process-keypress key))
      (ignore-screen-size)
      (expect joule/editor-state {:cx 3 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 138 :clipboard ["Hello, there"] :erows ["the quick brown fox jumps over the lazy dog" "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG" "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]" "b" "123"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))
