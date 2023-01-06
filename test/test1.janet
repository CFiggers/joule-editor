(use judge)
(import spork/test :as stest)

(import "/src/joule")
(import "/src/utilities")

### Testing Utilities ###

(defn ignore-screen-size []
  (set (joule/editor-state :screenrows) nil)
  (set (joule/editor-state :screencols) nil))

### Basic Functionality ###

(test editor-state-created
      # editor-state map exists
      (expect (truthy? joule/editor-state) true))

(test editor-state-reset
      # editor-state is default on-open state
      # Test function
      (joule/reset-editor-state)
      
      # Validate results
      (ignore-screen-size) 
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test editor-process-keystrokes
      # Set up test state
      (joule/reset-editor-state)

      # Test function
      (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
                 ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
                 ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter
                 97 98 99 :enter 49 50 51 
                 :uparrow :backspace :home :end :home :delete 
                 :downarrow :rightarrow :rightarrow :leftarrow
                 :pageup :pagedown]
            (joule/editor-process-keypress key))
      
      # Validate results
      (ignore-screen-size)
      (expect joule/editor-state {:cx 3 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 138 :clipboard ["Hello, there"] :erows ["the quick brown fox jumps over the lazy dog" "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG" "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]" "b" "123"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

# TODO: Test vertical scrolling

# TODO: Test horizontal scrolling

(test load-file-simple
      # Set up test state
      (joule/reset-editor-state)

      # Test function
      (joule/load-file "project.janet" :fake-text "yes")

      # Validate results
      (ignore-screen-size)
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

# (test load-file-modal-simple
#       # Set up test state
#       (joule/reset-editor-state)

#       # Test function
#       (with-binding 
#         (joule/load-file-modal :fake-text "project.janet"))

#       # Validate results
#       (ignore-screen-size)
#      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test jump-to-modal-simple
      # Set up test state
      (joule/reset-editor-state)
      (joule/load-file "project.janet")
      
      # Test function
      (joule/jump-to-modal :fake-text "4")
      
      #Validate results
      (ignore-screen-size)
      (expect joule/editor-state {:cx 0 :cy 3 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test find-in-text-modal-simple
      # Set up test state
      (joule/reset-editor-state)
      (joule/load-file "project.janet")
    
      # Mimic (find-in-text-modal)
      (joule/edset :search-active true)
      (joule/edset :modalinput "declare")
      (joule/set-temp-pos)

      (do (joule/find-all (joule/editor-state :modalinput))
          (unless (< 0 (utilities/safe-len (joule/editor-state :search-results)))
                  (joule/return-to-temp-pos)
                  (joule/clear-temp-pos)
                  (set joule/modal-rethome false)
                  (joule/edset :search-active nil)
                  (joule/send-status-msg "No matches found.")
                  (break))

          # Mimic (find-next true) -> (move-to-match)
          (do (let [all-results (joule/editor-state :search-results)
                    filter-fn (fn [[y x]] (or (> y (joule/abs-y)) (and (= y (joule/abs-y)) (> x (joule/abs-x)))))
                    next-results (sort (filter filter-fn all-results))
                    [y x] (or (first next-results) (first all-results))]
                (joule/jump-to y x)))

          # Mimic local (exit-search) binding
          (do (joule/clear-temp-pos)
              (joule/edset :search-active nil)))
      
      # Validate results
      (ignore-screen-size)
      (expect joule/editor-state {:cx 1 :cy 0 :modalinput "declare" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5} :search-results [[0 1] [9 1]]}))

(test editor-render-startup-with-welcome-message
      #Set up test state
      (joule/reset-editor-state)
      (var result @"")

      #Test function
      (with-dyns [:out (file/temp)]
        (joule/editor-refresh-screen {:default-sizes {:cols 100 :rows 40}})
        (file/seek (dyn :out) :set 0)
        (set result (string (file/read (dyn :out) :all))))

      #Validate results
      (expect result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n 13 \e[0;34m~\e[0;39m\e[K\r\n 14 \e[0;34m~\e[0;39m\e[K\r\n 15 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n 16 \e[0;34m~\e[0;39m                                              \e[K\r\n 17 \e[0;34m~\e[0;39m                                Ctrl + q                 quit\e[K\r\n 18 \e[0;34m~\e[0;39m                                Ctrl + l                 load\e[K\r\n 19 \e[0;34m~\e[0;39m                                Ctrl + s                 save\e[K\r\n 20 \e[0;34m~\e[0;39m                                Ctrl + a              save as\e[K\r\n 21 \e[0;34m~\e[0;39m                                Ctrl + f               search\e[K\r\n 22 \e[0;34m~\e[0;39m                                Ctrl + g       go (to line #)\e[K\r\n 23 \e[0;34m~\e[0;39m                                Ctrl + c                 copy\e[K\r\n 24 \e[0;34m~\e[0;39m                                Ctrl + p                paste\e[K\r\n 25 \e[0;34m~\e[0;39m                                Ctrl + n       toggle numbers\e[K\r\n 26 \e[0;34m~\e[0;39m\e[K\r\n 27 \e[0;34m~\e[0;39m\e[K\r\n 28 \e[0;34m~\e[0;39m\e[K\r\n 29 \e[0;34m~\e[0;39m\e[K\r\n 30 \e[0;34m~\e[0;39m\e[K\r\n 31 \e[0;34m~\e[0;39m\e[K\r\n 32 \e[0;34m~\e[0;39m\e[K\r\n 33 \e[0;34m~\e[0;39m\e[K\r\n 34 \e[0;34m~\e[0;39m\e[K\r\n 35 \e[0;34m~\e[0;39m\e[K\r\n 36 \e[0;34m~\e[0;39m\e[K\r\n 37 \e[0;34m~\e[0;39m\e[K\r\n 38 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(test editor-render-startup-without-welcome-message
      #Set up test state
      (joule/reset-editor-state)
      (var result @"")

      #Test function
      (with-dyns [:out (file/temp)]
        (joule/editor-refresh-screen {:default-sizes {:cols 100 :rows 14}})
        (file/seek (dyn :out) :set 0)
        (set result (string (file/read (dyn :out) :all))))

      #Validate results
      (expect result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

# TODO: Test render with text in editor-state

# TODO: Test render on vertical scroll

# TODO: Test render on horizontal scroll

# TODO: Test render on window resizing, with and without text loaded

# TODO: Test modals (especially cursor return positions)

# (test editor-search-while-finding-next
#       (joule/reset-editor-state)
#       (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
#                  ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
#                  ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter]
#             (joule/editor-process-keypress key))
#       (joule/edset :search-active true)
#       (joule/find-all "quick")
#       (move-to-match) 
#       (find-next)
#       (ignore-screen-size)
#       (expect joule/editor-state 0))