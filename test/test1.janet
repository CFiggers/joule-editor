(use judge)
(import spork/test :as stest)

(import "/src/joule")
(import "/src/utilities")

### Testing Utilities ###

(def start (os/clock))

(defn ignore-screen-size []
  (set (joule/editor-state :screenrows) nil)
  (set (joule/editor-state :screencols) nil))

(defn render-screen []
  (with-dyns [:out (file/temp)]
    (joule/editor-refresh-screen {:default-sizes {:cols 100 :rows 40}})))

(defmacro render-screen-return-result [res &opt cols rows]
  (default cols 100)
  (default rows 40)
  ~(with-dyns [:out (file/temp)]
        (joule/editor-refresh-screen {:default-sizes {:cols ,cols :rows ,rows}})
        (file/seek (dyn :out) :set 0)
        (set ,res (string (file/read (dyn :out) :all)))))

### Basic Functionality ###

(test editor-state-created
      # editor-state map exists
      (expect (truthy? joule/editor-state) true))

(test editor-state-reset
      # editor-state is default on-open state
      # Test function
      (joule/reset-editor-state)
      (render-screen)
      
      # Validate results
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

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
            (joule/editor-process-keypress key)
            (render-screen))
      
      # Validate results
      (expect joule/editor-state {:cx 3 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 138 :clipboard ["Hello, there"] :erows ["the quick brown fox jumps over the lazy dog" "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG" "1234567890 !@#$%^&*() `~|\\?/.>,<'\";:[{}]" "b" "123"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(defmacro test-arrows [dir expected]
  ~(test ,(symbol (string "arrows-" dir "-on-startup")) 
       # Set up test state
       (joule/reset-editor-state) 
       
       # Test function
       (each key [,;(seq [x :range [0 4]] (keyword (string dir "arrow")))]
             (joule/editor-process-keypress key)
             (render-screen))
       
       # Validate results
       (expect joule/editor-state ,expected)))

(test-arrows "right" {:cx 0 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}})
(test-arrows "left" {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}})
(test-arrows "up" {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}})
(test-arrows "down" {:cx 0 :cy 4 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "" :select-from {} :filetype "" :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows [] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}})

# TODO: Test PageUp going off top of document

# TODO: Test PageDown going off bottom of document

# TODO: Test mouse clicks inside of text

# TODO: Test mouse clicks outside of end of line of text

# TODO: Test mouse clicks below end of document

# TODO: Test mouse scrolling up, including past top of document

# TODO: Test mouse scrolling down, including past bottom of document

# TODO: Test vertical scrolling

# TODO: Test horizontal scrolling

(test load-file-simple
      #Set up test state
      (joule/reset-editor-state)

      #Test function
      (joule/load-file "project.janet" :fake-text "yes")
      (render-screen)

      #Validate results
      (ignore-screen-size)
      (expect joule/editor-state {:cx 0 :cy 0 :modalinput "" :coloffset 0 :statusmsg "" :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 4 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

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
      (render-screen)
      
      #Validate results
      (expect joule/editor-state {:cx 0 :cy 3 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

(test jump-to-modal-after-eof
      # Set up test state
      (joule/reset-editor-state) 
      (joule/update-screen-sizes {:rows 100 :cols 40})
      (joule/load-file "misc/test-joule.janet") 
      
      # Test function
      (joule/jump-to-modal :fake-text "200")
      (render-screen)
      
      #Validate results
      (expect joule/editor-state {:cx 0 :cy 48 :modalinput "" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 65 :filename "misc/test-joule.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows ["(use janet-termios)" "(import spork/path)" "(import \"/src/jermbox\")" "(use \"/src/syntax-highlights\")" "(use \"/src/utilities\")" "" "### Definitions ###" "" "(def version" "  \"0.0.5\")" "" "### Data ###" "" "(var joule-quit false)" "" "# TODO: Implement multiple \"tabs\"/buffers open simultaneously" "" "(var editor-state @{})" "" "(defn get-user-config []" "  (def user-home ((os/environ) \"HOME\"))" "  (def joulerc-path (path/join user-home \".joulerc\"))" "  (if (nil? (os/stat joulerc-path))" "    (let [default-config @{:scrollpadding 5" "                           :tabsize 2" "                           :indentwith :spaces" "                           :numtype true}]" "      (save-jdn default-config joulerc-path)" "      default-config)" "    (load-jdn joulerc-path)))" "" "(defn reset-editor-state :tested []" "  (set editor-state" "       @{:cx 0" "         :cy 0" "         :rememberx 0" "         :rowoffset 0" "         :coloffset 0" "         :erows @[]" "         :dirty 0" "         :linenumbers true" "         :leftmargin 3" "         :filename \"\"" "         :filetype \"\"" "         :statusmsg \"\"" "         :statusmsgtime 0" "         :modalmsg \"\"" "         :modalinput \"\"" "         :select-from @{}" "         :select-to @{}" "         :clipboard @[\"Hello, there\"]" "         :screenrows (- ((get-window-size) :rows) 2)" "         :screencols ((get-window-size) :cols)" "         :userconfig @{:scrollpadding 5" "                       :tabsize 2" "                       :indentwith :spaces" "                       :numtype :on}}))" "" "### Editor State Functions ###" "" "(defn abs-x []" "  (+ (editor-state :cx) (editor-state :coloffset)))" "" "(defn abs-y []" "  (+ (editor-state :cy) (editor-state :rowoffset)))" "" "(defn edset [& key-v]" "  (assert (= 0 (% (safe-len key-v) 2)))" "  (let [key-vs (partition 2 key-v)]" "    (each [key val] key-vs " "          (set (editor-state key) val))))" "" "(defn edup [& key-v]" "  (assert (= 0 (% (safe-len key-v) 2)))" "  (let [key-vs (partition 2 key-v)]" "    (each [key val] key-vs" "          (update editor-state key val))))" "" "(defn update-erow [row f]" "  (update-in editor-state [:erows row] f)" "  (edup :dirty inc))" "" "(defn update-minput [f]" "  (edup :modalinput f))" "" "(defn send-status-msg [msg]" "  (edset :statusmsg msg" "         :statusmsgtime (os/time)))" "" "(defn get-margin []" "  (if (editor-state :linenumbers)" "    (editor-state :leftmargin) 1))" "" "(defn rowlen [row]" "  (if-let [erow (get-in editor-state [:erows row])]" "    (safe-len erow) " "    0))" "" "(defn max-x [row]" "  (let [h-offset (editor-state :coloffset)]" "    (min (- (rowlen row) h-offset)" "         (editor-state :screencols))))" "" "(defn toggle-line-numbers []" "  (edup :linenumbers not))" "" "### Terminal ###" "" "(defn update-screen-sizes [&opt default-sizes]" "  (let [sizes (or default-sizes (get-window-size))]" "    (edset :screencols (sizes :cols)" "           :screenrows (- (sizes :rows) 2))))" "" "(defn handle-selection [dir] (if (selection-active?) (let [from (values (editor-state :select-from)) to (values (editor-state :select-to))] (cond (deep= @[(abs-x) (abs-y)] from) (case dir :left (grow-selection dir) :right (shrink-selection dir) :up (break) :down (break)) (deep= @[(abs-x) (abs-y)] to) (case dir :left (shrink-selection dir) :right (grow-selection dir) :up (break) :down (break)))) (do (edset :select-from @{:x (abs-x) :y (abs-y)} :select-to @{:x (abs-x) :y (abs-y)}) (grow-selection dir))))"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5}}))

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
      
      (render-screen)
      
      # Validate results
      (expect joule/editor-state {:cx 1 :cy 0 :modalinput "declare" :coloffset 0 :statusmsg "" :screencols 100 :modalmsg "" :statusmsgtime 0 :rowoffset 0 :filename "project.janet" :select-from {} :filetype :janet :linenumbers true :rememberx 0 :leftmargin 4 :screenrows 38 :dirty 0 :clipboard ["Hello, there"] :erows ["(declare-project" "  :name \"joule editor\"" "  :description \"A simple terminal-based text editor written in Janet.\"" "  :dependencies [\"https://www.github.com/andrewchambers/janet-jdn\"" "                 \"https://www.github.com/CFiggers/janet-termios\"" "                 \"https://www.github.com/janet-lang/spork\"" "                 \"https://www.github.com/CFiggers/jermbox\"" "                 \"https://github.com/ianthehenry/judge.git\"])" "" "(declare-executable " "  :name \"joule\"" "  :entry \"src/joule.janet\"" "  :lflags [\"-static\"]" "  :install false)"] :select-to {} :userconfig {:indentwith :spaces :numtype :on :tabsize 2 :scrollpadding 5} :search-results [[0 1] [9 1]]}))

(test editor-render-startup-with-welcome-message
      #Set up test state
      (joule/reset-editor-state)
      (var result @"")

      #Test function
      (render-screen-return-result result)

      #Validate results
      (expect result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n 13 \e[0;34m~\e[0;39m\e[K\r\n 14 \e[0;34m~\e[0;39m\e[K\r\n 15 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n 16 \e[0;34m~\e[0;39m                                              \e[K\r\n 17 \e[0;34m~\e[0;39m                                Ctrl + q                 quit\e[K\r\n 18 \e[0;34m~\e[0;39m                                Ctrl + l                 load\e[K\r\n 19 \e[0;34m~\e[0;39m                                Ctrl + s                 save\e[K\r\n 20 \e[0;34m~\e[0;39m                                Ctrl + a              save as\e[K\r\n 21 \e[0;34m~\e[0;39m                                Ctrl + f               search\e[K\r\n 22 \e[0;34m~\e[0;39m                                Ctrl + g       go (to line #)\e[K\r\n 23 \e[0;34m~\e[0;39m                                Ctrl + c                 copy\e[K\r\n 24 \e[0;34m~\e[0;39m                                Ctrl + p                paste\e[K\r\n 25 \e[0;34m~\e[0;39m                                Ctrl + n       toggle numbers\e[K\r\n 26 \e[0;34m~\e[0;39m\e[K\r\n 27 \e[0;34m~\e[0;39m\e[K\r\n 28 \e[0;34m~\e[0;39m\e[K\r\n 29 \e[0;34m~\e[0;39m\e[K\r\n 30 \e[0;34m~\e[0;39m\e[K\r\n 31 \e[0;34m~\e[0;39m\e[K\r\n 32 \e[0;34m~\e[0;39m\e[K\r\n 33 \e[0;34m~\e[0;39m\e[K\r\n 34 \e[0;34m~\e[0;39m\e[K\r\n 35 \e[0;34m~\e[0;39m\e[K\r\n 36 \e[0;34m~\e[0;39m\e[K\r\n 37 \e[0;34m~\e[0;39m\e[K\r\n 38 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(test editor-render-startup-without-welcome-message
      #Set up test state
      (joule/reset-editor-state)
      (var result @"")

      #Test function
      (render-screen-return-result result 100 14)

      #Validate results
      (expect result "\e[?25l\e[H  1 \e[0;34m~\e[0;39m\e[K\r\n  2 \e[0;34m~\e[0;39m\e[K\r\n  3 \e[0;34m~\e[0;39m\e[K\r\n  4 \e[0;34m~\e[0;39m\e[K\r\n  5 \e[0;34m~\e[0;39m\e[K\r\n  6 \e[0;34m~\e[0;39m\e[K\r\n  7 \e[0;34m~\e[0;39m                                Joule editor -- version 0.0.5\e[K\r\n  8 \e[0;34m~\e[0;39m\e[K\r\n  9 \e[0;34m~\e[0;39m\e[K\r\n 10 \e[0;34m~\e[0;39m\e[K\r\n 11 \e[0;34m~\e[0;39m\e[K\r\n 12 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4m\e[m                                                                                           1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(test editor-render-after-load-file
      #Set up test state
      (joule/reset-editor-state)
      (joule/load-file "misc/test-joule.janet")
      (var result @"")

      #Test function
      (render-screen-return-result result)

      #Validate results
      (expect result "\e[?25l\e[H  1 (\e[38;2;197;134;192muse\e[0;39m \e[38;2;156;220;254mjanet-termios\e[0;39m)\e[K\r\n  2 (\e[38;2;197;134;192mimport\e[0;39m \e[38;2;156;220;254mspork/path\e[0;39m)\e[K\r\n  3 (\e[38;2;197;134;192mimport\e[0;39m \e[38;2;206;145;120m\"/src/jermbox\"\e[0;39m)\e[K\r\n  4 (\e[38;2;197;134;192muse\e[0;39m \e[38;2;206;145;120m\"/src/syntax-highlights\"\e[0;39m)\e[K\r\n  5 (\e[38;2;197;134;192muse\e[0;39m \e[38;2;206;145;120m\"/src/utilities\"\e[0;39m)\e[K\r\n  6 \e[K\r\n  7 \e[38;2;106;153;85m### Definitions ###\e[0;39m\e[K\r\n  8 \e[K\r\n  9 (\e[38;2;197;134;192mdef\e[0;39m \e[38;2;156;220;254mversion\e[0;39m\e[K\r\n 10   \e[38;2;206;145;120m\"0.0.5\"\e[0;39m)\e[K\r\n 11 \e[K\r\n 12 \e[38;2;106;153;85m### Data ###\e[0;39m\e[K\r\n 13 \e[K\r\n 14 (\e[38;2;197;134;192mvar\e[0;39m \e[38;2;156;220;254mjoule-quit\e[0;39m \e[38;2;156;220;254mfalse\e[0;39m)\e[K\r\n 15 \e[K\r\n 16 \e[38;2;106;153;85m# TODO: Implement multiple \"tabs\"/buffers open simultaneously\e[0;39m\e[K\r\n 17 \e[K\r\n 18 (\e[38;2;197;134;192mvar\e[0;39m \e[38;2;156;220;254meditor-state\e[0;39m \e[38;2;156;220;254m@\e[0;39m{})\e[K\r\n 19 \e[K\r\n 20 (\e[38;2;197;134;192mdefn\e[0;39m \e[38;2;156;220;254mget-user-config\e[0;39m []\e[K\r\n 21   (\e[38;2;197;134;192mdef\e[0;39m \e[38;2;156;220;254muser-home\e[0;39m ((\e[38;2;156;220;254mos/environ\e[0;39m) \e[38;2;206;145;120m\"HOME\"\e[0;39m))\e[K\r\n 22   (\e[38;2;197;134;192mdef\e[0;39m \e[38;2;156;220;254mjoulerc-path\e[0;39m (\e[38;2;156;220;254mpath/join\e[0;39m \e[38;2;156;220;254muser-home\e[0;39m \e[38;2;206;145;120m\".joulerc\"\e[0;39m))\e[K\r\n 23   (\e[38;2;197;134;192mif\e[0;39m (\e[38;2;197;134;192mnil?\e[0;39m (\e[38;2;197;134;192mos/stat\e[0;39m \e[38;2;156;220;254mjoulerc-path\e[0;39m))\e[K\r\n 24     (\e[38;2;197;134;192mlet\e[0;39m [\e[38;2;156;220;254mdefault-config\e[0;39m \e[38;2;156;220;254m@\e[0;39m{\e[38;2;79;193;255m:scrollpadding\e[0;39m \e[38;2;181;206;168m5\e[0;39m\e[K\r\n 25                            \e[38;2;79;193;255m:tabsize\e[0;39m \e[38;2;181;206;168m2\e[0;39m\e[K\r\n 26                            \e[38;2;79;193;255m:indentwith\e[0;39m \e[38;2;79;193;255m:spaces\e[0;39m\e[K\r\n 27                            \e[38;2;79;193;255m:numtype\e[0;39m \e[38;2;156;220;254mtrue\e[0;39m}]\e[K\r\n 28       (\e[38;2;156;220;254msave-jdn\e[0;39m \e[38;2;156;220;254mdefault-config\e[0;39m \e[38;2;156;220;254mjoulerc-path\e[0;39m)\e[K\r\n 29       \e[38;2;156;220;254mdefault-config\e[0;39m)\e[K\r\n 30     (\e[38;2;156;220;254mload-jdn\e[0;39m \e[38;2;156;220;254mjoulerc-path\e[0;39m)))\e[K\r\n 31 \e[K\r\n 32 (\e[38;2;197;134;192mdefn\e[0;39m \e[38;2;156;220;254mreset-editor-state\e[0;39m \e[38;2;79;193;255m:tested\e[0;39m []\e[K\r\n 33   (\e[38;2;197;134;192mset\e[0;39m \e[38;2;156;220;254meditor-state\e[0;39m\e[K\r\n 34        \e[38;2;156;220;254m@\e[0;39m{\e[38;2;79;193;255m:cx\e[0;39m \e[38;2;181;206;168m0\e[0;39m\e[K\r\n 35          \e[38;2;79;193;255m:cy\e[0;39m \e[38;2;181;206;168m0\e[0;39m\e[K\r\n 36          \e[38;2;79;193;255m:rememberx\e[0;39m \e[38;2;181;206;168m0\e[0;39m\e[K\r\n 37          \e[38;2;79;193;255m:rowoffset\e[0;39m \e[38;2;181;206;168m0\e[0;39m\e[K\r\n 38          \e[38;2;79;193;255m:coloffset\e[0;39m \e[38;2;181;206;168m0\e[0;39m\e[K\r\n    \e[1;4mmisc/test-joule.janet\e[m                                                                      1:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(test editor-render-after-vertical-scroll
      # Set up test state
      (each key [:pagedown :pagedown :pagedown]
            (joule/editor-process-keypress key))
      (var result @"")

      #Test function
      (render-screen-return-result result)

      #Validate results
      (expect result "\e[?25l\e[H112            \e[38;2;79;193;255m:screenrows\e[0;39m (\e[38;2;197;134;192m-\e[0;39m (\e[38;2;156;220;254msizes\e[0;39m \e[38;2;79;193;255m:rows\e[0;39m) \e[38;2;181;206;168m2\e[0;39m))))\e[K\r\n113 \e[K\r\n114 (\e[38;2;197;134;192mdefn\e[0;39m \e[38;2;156;220;254mhandle-selection\e[0;39m [\e[38;2;156;220;254mdir\e[0;39m] (\e[38;2;197;134;192mif\e[0;39m (\e[38;2;156;220;254mselection-active?\e[0;39m) (\e[38;2;197;134;192mlet\e[0;39m [\e[38;2;156;220;254mfrom\e[0;39m (\e[38;2;197;134;192mvalues\e[0;39m (\e[38;2;156;220;254meditor-state\e[0;39m \e[38;2;79;193;255m:select-f\e[0;39m\e[K\r\n115 \e[0;34m~\e[0;39m\e[K\r\n116 \e[0;34m~\e[0;39m\e[K\r\n117 \e[0;34m~\e[0;39m\e[K\r\n118 \e[0;34m~\e[0;39m\e[K\r\n119 \e[0;34m~\e[0;39m\e[K\r\n120 \e[0;34m~\e[0;39m\e[K\r\n121 \e[0;34m~\e[0;39m\e[K\r\n122 \e[0;34m~\e[0;39m\e[K\r\n123 \e[0;34m~\e[0;39m\e[K\r\n124 \e[0;34m~\e[0;39m\e[K\r\n125 \e[0;34m~\e[0;39m\e[K\r\n126 \e[0;34m~\e[0;39m\e[K\r\n127 \e[0;34m~\e[0;39m\e[K\r\n128 \e[0;34m~\e[0;39m\e[K\r\n129 \e[0;34m~\e[0;39m\e[K\r\n130 \e[0;34m~\e[0;39m\e[K\r\n131 \e[0;34m~\e[0;39m\e[K\r\n132 \e[0;34m~\e[0;39m\e[K\r\n133 \e[0;34m~\e[0;39m\e[K\r\n134 \e[0;34m~\e[0;39m\e[K\r\n135 \e[0;34m~\e[0;39m\e[K\r\n136 \e[0;34m~\e[0;39m\e[K\r\n137 \e[0;34m~\e[0;39m\e[K\r\n138 \e[0;34m~\e[0;39m\e[K\r\n139 \e[0;34m~\e[0;39m\e[K\r\n140 \e[0;34m~\e[0;39m\e[K\r\n141 \e[0;34m~\e[0;39m\e[K\r\n142 \e[0;34m~\e[0;39m\e[K\r\n143 \e[0;34m~\e[0;39m\e[K\r\n144 \e[0;34m~\e[0;39m\e[K\r\n145 \e[0;34m~\e[0;39m\e[K\r\n146 \e[0;34m~\e[0;39m\e[K\r\n147 \e[0;34m~\e[0;39m\e[K\r\n148 \e[0;34m~\e[0;39m\e[K\r\n149 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4mmisc/test-joule.janet\e[m                                                                    112:0\e[K\r\n    \e[K\e[1;5H\e[?25h"))

(test editor-render-after-horizontal-scroll
      # Set up test state
      (joule/jump-to-modal :fake-text "200")
      (joule/editor-process-keypress :end)
      (var result @"")

      # Test function
      (render-screen-return-result result)

      # Validate results
      (expect result "\e[?25l\e[H 95 \e[K\r\n 96 \e[K\r\n 97 \e[K\r\n 98 \e[K\r\n 99 \e[K\r\n100 \e[K\r\n101 \e[K\r\n102 \e[K\r\n103 \e[K\r\n104 \e[K\r\n105 \e[K\r\n106 \e[K\r\n107 \e[K\r\n108 \e[K\r\n109 \e[K\r\n110 \e[K\r\n111 \e[K\r\n112 \e[K\r\n113 \e[K\r\n114 \e[38;2;156;220;254mfrom\e[0;39m \e[38;2;156;220;254m@\e[0;39m{\e[38;2;79;193;255m:x\e[0;39m (\e[38;2;156;220;254mabs-x\e[0;39m) \e[38;2;79;193;255m:y\e[0;39m (\e[38;2;156;220;254mabs-y\e[0;39m)} \e[38;2;79;193;255m:select-to\e[0;39m \e[38;2;156;220;254m@\e[0;39m{\e[38;2;79;193;255m:x\e[0;39m (\e[38;2;156;220;254mabs-x\e[0;39m) \e[38;2;79;193;255m:y\e[0;39m (\e[38;2;156;220;254mabs-y\e[0;39m)}) (\e[38;2;156;220;254mgrow-selection\e[0;39m \e[38;2;156;220;254mdir\e[0;39m))))\e[K\r\n115 \e[0;34m~\e[0;39m\e[K\r\n116 \e[0;34m~\e[0;39m\e[K\r\n117 \e[0;34m~\e[0;39m\e[K\r\n118 \e[0;34m~\e[0;39m\e[K\r\n119 \e[0;34m~\e[0;39m\e[K\r\n120 \e[0;34m~\e[0;39m\e[K\r\n121 \e[0;34m~\e[0;39m\e[K\r\n122 \e[0;34m~\e[0;39m\e[K\r\n123 \e[0;34m~\e[0;39m\e[K\r\n124 \e[0;34m~\e[0;39m\e[K\r\n125 \e[0;34m~\e[0;39m\e[K\r\n126 \e[0;34m~\e[0;39m\e[K\r\n127 \e[0;34m~\e[0;39m\e[K\r\n128 \e[0;34m~\e[0;39m\e[K\r\n129 \e[0;34m~\e[0;39m\e[K\r\n130 \e[0;34m~\e[0;39m\e[K\r\n131 \e[0;34m~\e[0;39m\e[K\r\n132 \e[0;34m~\e[0;39m\e[K\r\n    \e[1;4mmisc/test-joule.janet\e[m                                                                  114:507\e[K\r\n    \e[K\e[20;95H\e[?25h"))

(test final-time
      (print "Elapsed time: " (- (os/clock) start) " seconds"))

# (test editor-jump-home-on-empty-line 
#       # Set up test state
       
       
#       # Test function
       
       
#       # Validate results
#       (expect  0))

# (test editor-jump-home-on-empty-line-offscreen 
#       # Set up test state
       
       
#       # Test function
       
       
#       # Validate results
#       (expect  0))

# TODO: Test render on window resizing, with and without text loaded

# TODO: Test modals (especially cursor return positions)

# TODO: Test combination of mouse behavior (clicks, scrolling) with active Modal

# TODO: Test combination of mouse behaviro (clicks, scrolling) with active find-next

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

# TODO: Test file type detection

# TODO: Test sytax highlighting for Janet

# TODO: Test syntax highlighting for C
