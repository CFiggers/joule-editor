(use judge)

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
      #editor-state is default on-open state
      (joule/reset-editor-state)
      (ignore-screen-size)
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test editor-process-keystrokes
      (joule/reset-editor-state)
      (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
                 ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
                 ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter
                 97 98 99 :enter 49 50 51 
                 :uparrow :backspace :home :end :home :delete 
                 :downarrow :rightarrow :rightarrow :leftarrow
                 :pageup :pagedown]
            (joule/editor-process-keypress key))
      (ignore-screen-size)
      (expect joule/editor-state {:cx 3 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 3 :dirty 138 :clipboard ["Hello, there"] :erows ["the quick brown fox jumps over the lazy dog" "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG" "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]" "b" "123"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test find-in-text-modal-simple
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
      (ignore-screen-size)
      (expect joule/editor-state {:cx 1 :cy 0 :modalinput "declare" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5} :search-results [[0 1] [9 1]]}))

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