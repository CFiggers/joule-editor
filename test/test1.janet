(use judge)

(import "/src/joule")
(import "/src/utilities")
(use "/test/test-utils")

(def start (os/clock))

### Basic Functionality ###

(deftest editor-state-created
      # editor-state map exists
      (test (truthy? joule/editor-state) true))

(deftest editor-state-reset
      # editor-state is default on-open state
      # Test function
      (joule/reset-editor-state)
      (render-screen)
      
      # Validate results
      (test joule/editor-state @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor editor-process-keystrokes [_]
      # Test function
      (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
                 ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
                 ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter
                 97 98 99 :enter 49 50 51 
                 :uparrow :backspace :home :end :home :delete 
                 :downarrow :rightarrow :rightarrow :leftarrow
                 :pageup :pagedown]
            (joule/editor-process-keypress key)
            (render-screen))
      
      # Validate results
      (test joule/editor-state @{:clipboard @["Hello, there"] :coloffset 0 :cx 3 :cy 4 :dirty 138 :erows @["the quick brown fox jumps over the lazy dog" "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG" "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]" "b" "123"] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

### Test Arrow Keys on Startup

(deftest: with-fresh-editor arrows-right-on-startup [_] 
  (each key [;(seq [x :range [0 4]] :rightarrow)]
        (joule/editor-process-keypress key)
        (render-screen))
  
  (test joule/editor-state 
        @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 4 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor arrows-left-on-startup [_]
  (each key [(seq [x :range [0 4]] :leftarrow)]
        (joule/editor-process-keypress key)
        (render-screen))
  
  (test joule/editor-state 
        @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor arrows-up-on-startup [_]
  (each key [(seq [x :range [0 4]] :uparrow)]
        (joule/editor-process-keypress key)
        (render-screen))
  
  (test joule/editor-state
        @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{:indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor arrows-down-on-startup [_]
  (each key [(seq [x :range [0 4]] :downarrow)]
        (joule/editor-process-keypress key)
        (render-screen))
  
  (test joule/editor-state
        @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{:indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

### Test Home and End

(deftest: with-fresh-editor move-cursor-end [_]
  # Set up test state
  (joule/load-file "misc/test-joule.janet.test")
  (joule/jump-to 114 0)

  (test (joule/editor-state :cx) 0)
  (test (joule/editor-state :coloffset) 0)

  # Test function

  (joule/move-cursor-end)

  # Validate results
  (test (joule/editor-state :cx) 90)
  (test (joule/editor-state :coloffset) 417))

(deftest: with-fresh-editor move-cursor-home [_]
  # Set up test state
  (joule/load-file "misc/test-joule.janet.test")
  (joule/jump-to 114 0)
  (joule/move-cursor-end)

  (test (joule/editor-state :cx) 90)
  (test (joule/editor-state :coloffset) 417)

  # Test function

  (joule/move-cursor-home)

  # Validate results
  (test (joule/editor-state :cx) 0)
  (test (joule/editor-state :coloffset) 0))


# # TODO: Test PageUp going off top of document

# TODO: Test PageDown going off bottom of document

# TODO: Test mouse clicks inside of text

# TODO: Test mouse clicks outside of end of line of text

# TODO: Test mouse clicks below end of document

# TODO: Test mouse scrolling up, including past top of document

# TODO: Test mouse scrolling down, including past bottom of document

# TODO: Test vertical scrolling

# TODO: Test horizontal scrolling

(deftest: with-fresh-editor load-file-simple [_]
      #Test function
      (joule/load-file "project.janet" :fake-text "yes")
      (render-screen)

      #Validate results
      (default-screen-size)
      (test joule/editor-state @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[ "(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :filename "project.janet" :filetype :janet :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 40 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

# (deftest load-file-modal-simple
#       # Set up test state
#       (joule/reset-editor-state)

#       # Test function
#       (with-binding 
#         (joule/load-file-modal :fake-text "project.janet"))

#       # Validate results
#       (default-screen-size)
#      (test joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 3 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(deftest: with-fresh-editor jump-to-modal-simple [_]
      # Set up test state
      (joule/load-file "project.janet")
      
      # Test function
      (joule/jump-to-modal :fake-text "4")
      (render-screen)
      
      #Validate results
      (test joule/editor-state @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 3 :dirty 0 :erows @[ "(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :filename "project.janet" :filetype :janet :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor jump-to-modal-after-eof [_]
      # Set up test state
      (joule/load-file "misc/test-joule.janet.test") 
      
      # Test function
      (joule/jump-to-modal :fake-text "200")
      (render-screen)
      
      # Validate results
      (test joule/editor-state 
            @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 20 :dirty 0 :erows @[ "(use janet-termios)" "(import spork/path)" "(import \"/src/jermbox\")" "(use \"/src/syntax-highlights\")" "(use \"/src/utilities\")" "" "### Definitions ###" "" "(def version" "  \"0.0.5\")" "" "### Data ###" "" "(var joule-quit false)" "" "# TODO: Implement multiple \"tabs\"/buffers open simultaneously" "" "(var editor-state @{})" "" "(defn get-user-config []" "  (def user-home ((os/environ) \"HOME\"))" "  (def joulerc-path (path/join user-home \".joulerc\"))" "  (if (nil? (os/stat joulerc-path))" "    (let [default-config @{:scrollpadding 5" "                           :tabsize 2" "                           :indentwith :spaces" "                           :numtype true}]" "      (save-jdn default-config joulerc-path)" "      default-config)" "    (load-jdn joulerc-path)))" "" "(defn reset-editor-state :tested []" "  (set editor-state" "       @{:cx 0" "         :cy 0" "         :rememberx 0" "         :rowoffset 0" "         :coloffset 0" "         :erows @[]" "         :dirty 0" "         :linenumbers true" "         :leftmargin 3" "         :filename \"\"" "         :filetype \"\"" "         :statusmsg \"\"" "         :statusmsgtime 0" "         :modalmsg \"\"" "         :modalinput \"\"" "         :select-from @{}" "         :select-to @{}" "         :clipboard @[\"Hello, there\"]" "         :screenrows (- ((get-window-size) :rows) 2)" "         :screencols ((get-window-size) :cols)" "         :userconfig @{:scrollpadding 5" "                       :tabsize 2" "                       :indentwith :spaces" "                       :numtype :on}}))" "" "### Editor State Functions ###" "" "(defn abs-x []" "  (+ (editor-state :cx) (editor-state :coloffset)))" "" "(defn abs-y []" "  (+ (editor-state :cy) (editor-state :rowoffset)))" "" "(defn edset [& key-v]" "  (assert (= 0 (% (safe-len key-v) 2)))" "  (let [key-vs (partition 2 key-v)]" "    (each [key val] key-vs " "          (set (editor-state key) val))))" "" "(defn edup [& key-v]" "  (assert (= 0 (% (safe-len key-v) 2)))" "  (let [key-vs (partition 2 key-v)]" "    (each [key val] key-vs" "          (update editor-state key val))))" "" "(defn update-erow [row f]" "  (update-in editor-state [:erows row] f)" "  (edup :dirty inc))" "" "(defn update-minput [f]" "  (edup :modalinput f))" "" "(defn send-status-msg [msg]" "  (edset :statusmsg msg" "         :statusmsgtime (os/time)))" "" "(defn get-margin []" "  (if (editor-state :linenumbers)" "    (editor-state :leftmargin) 1))" "" "(defn rowlen [row]" "  (if-let [erow (get-in editor-state [:erows row])]" "    (safe-len erow) " "    0))" "" "(defn max-x [row]" "  (let [h-offset (editor-state :coloffset)]" "    (min (- (rowlen row) h-offset)" "         (editor-state :screencols))))" "" "(defn toggle-line-numbers []" "  (edup :linenumbers not))" "" "### Terminal ###" "" "(defn update-screen-sizes [&opt default-sizes]" "  (let [sizes (or default-sizes (get-window-size))]" "    (edset :screencols (sizes :cols)" "           :screenrows (- (sizes :rows) 2))))" "" "(defn handle-selection [dir] (if (selection-active?) (let [from (values (editor-state :select-from)) to (values (editor-state :select-to))] (cond (deep= @[(abs-x) (abs-y)] from) (case dir :left (grow-selection dir) :right (shrink-selection dir) :up (break) :down (break)) (deep= @[(abs-x) (abs-y)] to) (case dir :left (shrink-selection dir) :right (grow-selection dir) :up (break) :down (break)))) (do (edset :select-from @{:x (abs-x) :y (abs-y)} :select-to @{:x (abs-x) :y (abs-y)}) (grow-selection dir))))"] :filename "misc/test-joule.janet.test" :filetype :txt :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 93 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor find-in-text-modal-simple [_]
      # Set up test state
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
      
      (render-screen)
      
      # Validate results
      (test joule/editor-state @{:clipboard @["Hello, there"] :coloffset 0 :cx 1 :cy 0 :dirty 0 :erows @[ "(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :filename "project.janet" :filetype :janet :leftmargin 4 :linenumbers true :modalinput "declare" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :search-results @[[0 1] [9 1]] :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}}))

(deftest: with-fresh-editor editor-render-startup-with-welcome-message [_]
      #Set up test state
      (var result @"")

      #Test function
      (render-screen-return-result result)

      #Validate results
      (test result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n 13 \e[0;34m~\e[0;39m\e[K\r\n 14 \e[0;34m~\e[0;39m\e[K\r\n 15 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n 16 \e[0;34m~\e[0;39m                                              \e[K\r\n 17 \e[0;34m~\e[0;39m                                Ctrl + q                 quit\e[K\r\n 18 \e[0;34m~\e[0;39m                                Ctrl + l                 load\e[K\r\n 19 \e[0;34m~\e[0;39m                                Ctrl + s                 save\e[K\r\n 20 \e[0;34m~\e[0;39m                                Ctrl + a              save as\e[K\r\n 21 \e[0;34m~\e[0;39m                                Ctrl + f               search\e[K\r\n 22 \e[0;34m~\e[0;39m                                Ctrl + g       go (to line #)\e[K\r\n 23 \e[0;34m~\e[0;39m                                Ctrl + c                 copy\e[K\r\n 24 \e[0;34m~\e[0;39m                                Ctrl + p                paste\e[K\r\n 25 \e[0;34m~\e[0;39m                                Ctrl + n       toggle numbers\e[K\r\n 26 \e[0;34m~\e[0;39m\e[K\r\n 27 \e[0;34m~\e[0;39m\e[K\r\n 28 \e[0;34m~\e[0;39m\e[K\r\n 29 \e[0;34m~\e[0;39m\e[K\r\n 30 \e[0;34m~\e[0;39m\e[K\r\n 31 \e[0;34m~\e[0;39m\e[K\r\n 32 \e[0;34m~\e[0;39m\e[K\r\n 33 \e[0;34m~\e[0;39m\e[K\r\n 34 \e[0;34m~\e[0;39m\e[K\r\n 35 \e[0;34m~\e[0;39m\e[K\r\n 36 \e[0;34m~\e[0;39m\e[K\r\n 37 \e[0;34m~\e[0;39m\e[K\r\n 38 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(deftest: with-fresh-editor editor-render-startup-without-welcome-message [_]
      #Set up test state
      (var result @"")

      #Test function
      (render-screen-return-result result 100 14)

      #Validate results
      (test result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(deftest: with-fresh-editor editor-render-after-load-file [_]
  #Set up test state
  (joule/load-file "misc/test-joule.janet.test")
  (var result @"")

  #Test function
  (render-screen-return-result result)

  #Validate results
  (test result "\e[?25l\e[H  1 (use janet-termios)\e[K\r\n  2 (import spork/path)\e[K\r\n  3 (import \"/src/jermbox\")\e[K\r\n  4 (use \"/src/syntax-highlights\")\e[K\r\n  5 (use \"/src/utilities\")\e[K\r\n  6 \e[K\r\n  7 ### Definitions ###\e[K\r\n  8 \e[K\r\n  9 (def version\e[K\r\n 10   \"0.0.5\")\e[K\r\n 11 \e[K\r\n 12 ### Data ###\e[K\r\n 13 \e[K\r\n 14 (var joule-quit false)\e[K\r\n 15 \e[K\r\n 16 # TODO: Implement multiple \"tabs\"/buffers open simultaneously\e[K\r\n 17 \e[K\r\n 18 (var editor-state @{})\e[K\r\n 19 \e[K\r\n 20 (defn get-user-config []\e[K\r\n 21   (def user-home ((os/environ) \"HOME\"))\e[K\r\n 22   (def joulerc-path (path/join user-home \".joulerc\"))\e[K\r\n 23   (if (nil? (os/stat joulerc-path))\e[K\r\n 24     (let [default-config @{:scrollpadding 5\e[K\r\n 25                            :tabsize 2\e[K\r\n 26                            :indentwith :spaces\e[K\r\n 27                            :numtype true}]\e[K\r\n 28       (save-jdn default-config joulerc-path)\e[K\r\n 29       default-config)\e[K\r\n 30     (load-jdn joulerc-path)))\e[K\r\n 31 \e[K\r\n 32 (defn reset-editor-state :tested []\e[K\r\n 33   (set editor-state\e[K\r\n 34        @{:cx 0\e[K\r\n 35          :cy 0\e[K\r\n 36          :rememberx 0\e[K\r\n 37          :rowoffset 0\e[K\r\n 38          :coloffset 0\e[K\r\n    \e[1;4mmisc/test-joule.janet.test\e[m                                                                 1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(deftest: with-fresh-editor editor-render-after-vertical-scroll [_]
  #Set up test state
  (joule/load-file "misc/test-joule.janet.test")

  (each key [:pagedown :pagedown :pagedown]
        (joule/editor-process-keypress key))
  (var result @"")

  #Test function
  (render-screen-return-result result)

  #Validate results
  (test result "\e[?25l\e[H 79 defn update-erow [row f]\e[K\r\n 80  (update-in editor-state [:erows row] f)\e[K\r\n 81  (edup :dirty inc))\e[K\r\n 82 \e[K\r\n 83 defn update-minput [f]\e[K\r\n 84  (edup :modalinput f))\e[K\r\n 85 \e[K\r\n 86 defn send-status-msg [msg]\e[K\r\n 87  (edset :statusmsg msg\e[K\r\n 88         :statusmsgtime (os/time)))\e[K\r\n 89 \e[K\r\n 90 defn get-margin []\e[K\r\n 91  (if (editor-state :linenumbers)\e[K\r\n 92    (editor-state :leftmargin) 1))\e[K\r\n 93 \e[K\r\n 94 defn rowlen [row]\e[K\r\n 95  (if-let [erow (get-in editor-state [:erows row])]\e[K\r\n 96    (safe-len erow) \e[K\r\n 97    0))\e[K\r\n 98 \e[K\r\n 99 defn max-x [row]\e[K\r\n100  (let [h-offset (editor-state :coloffset)]\e[K\r\n101    (min (- (rowlen row) h-offset)\e[K\r\n102         (editor-state :screencols))))\e[K\r\n103 \e[K\r\n104 defn toggle-line-numbers []\e[K\r\n105  (edup :linenumbers not))\e[K\r\n106 \e[K\r\n107 ## Terminal ###\e[K\r\n108 \e[K\r\n109 defn update-screen-sizes [&opt default-sizes]\e[K\r\n110  (let [sizes (or default-sizes (get-window-size))]\e[K\r\n111    (edset :screencols (sizes :cols)\e[K\r\n112           :screenrows (- (sizes :rows) 2))))\e[K\r\n113 \e[K\r\n114 defn handle-selection [dir] (if (selection-active?) (let [from (values (editor-state :select-fro\e[K\r\n115 \e[0;34m~\e[0;39m\e[K\r\n116 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4mmisc/test-joule.janet.test\e[m                                                             114:100\e[K\r\n    \e[K\e[36;104H\e[?25h"))

(deftest: with-fresh-editor editor-render-after-horizontal-scroll [_]
  #Set up test state
  (joule/load-file "misc/test-joule.janet.test")
  (joule/jump-to-modal :fake-text "200")
  (joule/editor-process-keypress :end)
  (var result @"")

  #Test function
  (render-screen-return-result result)

  #Validate results
  (test result "\e[?25l\e[H 94 \e[K\r\n 95 \e[K\r\n 96 \e[K\r\n 97 \e[K\r\n 98 \e[K\r\n 99 \e[K\r\n100 \e[K\r\n101 \e[K\r\n102 \e[K\r\n103 \e[K\r\n104 \e[K\r\n105 \e[K\r\n106 \e[K\r\n107 \e[K\r\n108 \e[K\r\n109 \e[K\r\n110 \e[K\r\n111 \e[K\r\n112 \e[K\r\n113 \e[K\r\n114 from @{:x (abs-x) :y (abs-y)} :select-to @{:x (abs-x) :y (abs-y)}) (grow-selection dir))))\e[K\r\n115 \e[0;34m~\e[0;39m\e[K\r\n116 \e[0;34m~\e[0;39m\e[K\r\n117 \e[0;34m~\e[0;39m\e[K\r\n118 \e[0;34m~\e[0;39m\e[K\r\n119 \e[0;34m~\e[0;39m\e[K\r\n120 \e[0;34m~\e[0;39m\e[K\r\n121 \e[0;34m~\e[0;39m\e[K\r\n122 \e[0;34m~\e[0;39m\e[K\r\n123 \e[0;34m~\e[0;39m\e[K\r\n124 \e[0;34m~\e[0;39m\e[K\r\n125 \e[0;34m~\e[0;39m\e[K\r\n126 \e[0;34m~\e[0;39m\e[K\r\n127 \e[0;34m~\e[0;39m\e[K\r\n128 \e[0;34m~\e[0;39m\e[K\r\n129 \e[0;34m~\e[0;39m\e[K\r\n130 \e[0;34m~\e[0;39m\e[K\r\n131 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4mmisc/test-joule.janet.test\e[m                                                             114:507\e[K\r\n    \e[K\e[21;95H\e[?25h"))

(deftest final-time
      (print "Elapsed time: " (- (os/clock) start) " seconds"))

# (deftest editor-jump-home-on-empty-line 
#       # Set up test state
       
       
#       # Test function
       
       
#       # Validate results
#       (test  0))

# (deftest editor-jump-home-on-empty-line-offscreen 
#       # Set up test state
       
       
#       # Test function
       
       
#       # Validate results
#       (test  0))

# TODO: Test render on window resizing, with and without text loaded

# TODO: Test modals (especially cursor return positions)

# TODO: Test combination of mouse behavior (clicks, scrolling) with active Modal

# TODO: Test combination of mouse behaviro (clicks, scrolling) with active find-next

# (deftest editor-search-while-finding-next
#       (joule/reset-editor-state)
#       (each key [;(string/bytes "the quick brown fox jumps over the lazy dog") :enter
#                  ;(string/bytes "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG") :enter
#                  ;(string/bytes "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]") :enter]
#             (joule/editor-process-keypress key))
#       (joule/edset :search-active true)
#       (joule/find-all "quick")
#       (move-to-match) 
#       (find-next)
#       (default-screen-size)
#       (test joule/editor-state 0))

# TODO: Test file type detection

# TODO: Test sytax highlighting for Janet

# TODO: Test syntax highlighting for C
