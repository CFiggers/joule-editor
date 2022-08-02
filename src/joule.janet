(use janet-termios)
(use "./core-fns")

### Definitions ###

(def version
  "0.0.1")

(def keymap
  {9 :tab
   13 :enter
   27 :esc
   127 :backspace
   1000 :leftarrow
   1001 :rightarrow
   1002 :uparrow
   1003 :downarrow
   1004 :pageup
   1005 :pagedown
   1006 :home
   1007 :end
   1008 :del
   1009 :ctrlleftarrow
   1010 :ctrlrightarrow
   1011 :ctrluparrow
   1012 :ctrldownarrow
   1013 :shiftleftarrow
   1014 :shiftrightarrow
   1015 :shiftuparrow
   1016 :shiftdownarrow})

### Data ###

(var quit false)

# TODO: Implement multiple "tabs"/buffers open simultaneously

(var editor-state @{})

(defn reset-editor-state []
     (set editor-state
          @{:cx 0
            :cy 0
            :rememberx 0
            :rowoffset 0
            :coloffset 0
            :erows @[]
            :dirty 0
            :linenumbers true
            :leftmargin 3
            :filename ""
            :filetype ""
            :statusmsg ""
            :statusmsgtime 0
            :modalmsg ""
            :modalinput ""
            :screenrows (- ((get-window-size) :rows) 2)
            :screencols ((get-window-size) :cols)
            :userconfig @{:scrollpadding 5
                          :tabsize 2
                          :indentwith :spaces
                          :numtype :on}}))

### Utility Functions ###

(defn esc [c]
  (string "\x1b[" c))

(defn ctrl-key [k]
  (band k 0x1f))

(defn safe-len [arg]
  (try (length arg) ([err fib] 0)))

(defn zipwith [f col1 col2]
  (var result @[])
  (let [n (min (safe-len col1) (safe-len col2))]
    (for i 0 n
         (array/push result (f (get col1 i) (get col2 i))))
    result))

(defn abs-x []
  (+ (editor-state :cx) (editor-state :coloffset)))

(defn abs-y []
  (+ (editor-state :cy) (editor-state :rowoffset)))

(defn string/insert [str at & xs]
  (def at (if (= -1 at) (length str) at))
  (assert (<= at (length str)) 
          "Can't string/insert: `at` larger than `str`")
  (string
     (string/slice str 0 at)
     (string ;xs)
     (string/slice str (- (inc (- (length str) at))))))

(defn string/cut [str at &opt until]
  (assert (>= at 0) "Can't string/cut: `at` is negative")
  (assert (>= until at) "Can't string/cut: `until` is less than `at`")
  (if (not until)
   (string 
     (string/slice str 0 at)
     (string/slice str (- at (length str))))))

(defn edset [& key-v]
  (assert (= 0 (% (safe-len key-v) 2)))
  (let [key-vs (partition 2 key-v)]
    (each [key val] key-vs 
          (set (editor-state key) val))))

(defn edup [& key-v]
  (assert (= 0 (% (safe-len key-v) 2)))
  (let [key-vs (partition 2 key-v)]
    (each [key val] key-vs 
          (update editor-state key val))))

(defn update-erow [row f]
  (update-in editor-state [:erows row] f)
  (edup :dirty inc))

(defn update-minput [f]
  (edup :modalinput f))

(defn color 
  ```
  Return `text` surrounded by ANSI color codes corresponding to `color-key`.
   
  Options are: 
  - :black 
  - :red
  - :green 
  - :yellow
  - :blue 
  - :magenta
  - :cyan 
  - :white
  - :brown
  - :default
  ```
  [text color-key]
  (if-let [color-code
           (case color-key
             :black "0;30" :red "0;31"
             :green "0;32" :yellow "0;33"
             :blue "0;34" :magenta "38;2;197;134;192"
             :cyan "0;36" :white "0;37"
             :brown "38;2;206;145;120"
             :cream-green "38;2;181;206;168"
             :powder-blue "38;2;156;220;254"
             :drab-green "38;2;106;153;85"
             :default "0;39")] 
    (string "\e[" color-code "m" text "\e[0m")
    text))

(defn bg-color
  
  [text color-key]
  (if-let [color-code
           (case color-key
             :black 0 :red 1
             :green 2 :yellow 3
             :blue 4 :magenta 5
             :cyan 6 :white 7
             :default 9)]
    (string "\e[0;4" color-code "m" text "\e[0m")
    text))

### Editor State Functions ###

(defn send-status-msg [msg]
  (edset :statusmsg msg
         :statusmsgtime (os/time)))

(defn get-margin []
  (if (editor-state :linenumbers)
    (editor-state :leftmargin) 1))

(defn rowlen [row]
  (if-let [erow (get-in editor-state [:erows row])]
    (safe-len erow) 
    0))

(defn max-x [row]
  (let [h-offset (editor-state :coloffset)]
    (min (- (rowlen row) h-offset)
         (editor-state :screencols))))

(defn toggle-line-numbers []
  (edup :linenumbers not))

### Terminal ###

(defn update-screen-sizes []
  (let [sizes (get-window-size)]
    (edset :screencols (sizes :cols)
           :screenrows (- (sizes :rows) 2))))

### Movement ###

# TODO: Implement buffer of lines to keep at top/bottom of screen
# when scrolling up/down, based on [:userconfig :scrollpadding]

(defn move-viewport [direction]
  (case direction
    :up (edup :rowoffset dec)
    :down (edup :rowoffset inc)
    :left (edup :coloffset dec)
    :right (edup :coloffset inc)
    
    :home (edset :coloffset 0)
    :end (edset :coloffset
                (+ 10 (- (rowlen (abs-y))
                         (editor-state :screencols))))
    
    :pageup (edset :rowoffset
                   (max 0 (- (editor-state :rowoffset)
                             (dec (editor-state :screenrows)))))
    :pagedown (edset :rowoffset
                     (+ (editor-state :rowoffset)
                        (dec (editor-state :screenrows))))))

(defn move-cursor-home []
  (move-viewport :home)
  (edset :cx 0))

(defn move-cursor-end []
  (let [row-len (rowlen (abs-y))
        screen-h (- (editor-state :screencols) (get-margin))]
    (if (> row-len screen-h)
      (move-viewport :end)
      (move-viewport :home))
    (edset :cx (max-x (abs-y)))))

(defn move-cursor [direction]
  (case direction 
    :up (edup :cy dec)
    :down (edup :cy inc)
    :left (edup :cx dec)
    :right (edup :cx inc)
    :home (move-cursor-home)
    :end (move-cursor-end)))

(defn editor-scroll []
  (let [cx (editor-state :cx)
        cy (editor-state :cy)]
    
    # Cursor off screen Top
    (when (< cy 0) 
      (do (when (> (editor-state :rowoffset) 0) 
            (move-viewport :up))
          (edset :cy 0)))
    
    # Cursor off screen Bottom
    (when (>= cy (editor-state :screenrows))
      (do (move-viewport :down)
          (move-cursor :up)))
    
    # Cursor off screen Left
    (when (< cx 0)
      (do (when (> (editor-state :coloffset) 0)
            (move-viewport :left))
          (edset :cx 0)))
    
    # Cursor off screen Right
    (when (>= cx (- (editor-state :screencols) (get-margin)))
      (do (move-viewport :right)
          (edup :cx dec)))))

(defn move-cursor-with-mem [direction]
  (let [currenty (abs-y)
        cx (editor-state :cx)]
    (move-cursor direction)
    # Move cursor to either end of new line (if shorter)
    # or same point on line as x memory (if longer)
    (let [f (case direction :up dec :down inc)]
      (edset :cx (min (max (editor-state :rememberx) cx)
                      (max-x (f currenty)))))))

(defn update-x-memory [cx]
  (when (> cx (editor-state :rememberx))
    (edset :rememberx cx)))

(defn wrap-to-end-of-prev-line []
  (move-cursor :up)
  (move-cursor :end))

(defn wrap-to-start-of-next-line []
  (move-cursor :down)
  (move-cursor :home))

### Syntax Highlighting ### 

# TODO: Correctly color strings across line breaks
# TODO: Janet Long strings w/ ``` syntax
# TODO: Extensible syntax highlighting scheme

(def highlight-rules
  (peg/compile ~{:comment (replace (<- (* "#" (any 1))) ,|(color $ :drab-green))
                 :string (replace (<- (* "\"" (to "\"") "\"")) ,|(color $ :brown))
                 :ws (<- (set " \t\r\f\n\0\v"))
                 :delim (+ :ws (set "([{\"`}])"))
                 :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
                 :numbers (replace (<- (some (+ :d "."))) ,|(color $ :cream-green))
                 :keyword (replace (<- (* ":" (some :symchars))) ,|(color $ :magenta)) 
                 :symbol (replace (<- (some (+ :symchars "-"))) ,|(color $ :powder-blue))
                 :special (replace (* (<- (+ ,;core-fns ,;special-forms)) :ws) ,|(string (color $0 :magenta) $1)) 
                 :else (<- 1)
                 :value (+ :comment :string :numbers :keyword :special :symbol :ws :else)
                 :main (some :value)}))

(defn insert-highlight [str]
  (if (= str "") "" 
    (string/join (peg/match highlight-rules str))))

### Output ###

(defn add-syntax-hl [rows]
  (map insert-highlight rows))

(defn fuse-over [priority secondary]
  (let [dup (array/slice priority)]
    (array/concat dup (drop (safe-len priority) secondary))))

(defn add-welcome-message [rows]
  (def messages @[(string "Joule editor -- version " version)
                  ""
                  "Ctrl + q                 quit"
                  "Ctrl + l                 load"
                  "Ctrl + s                 save"
                  "Ctrl + a              save as"
                  "Ctrl + f               search"
                  "Ctrl + n       toggle numbers"])
  (if (deep= @[] (flatten (editor-state :erows)))
    (let [r (editor-state :screenrows)
          c (editor-state :screencols)
          message-start-row (- (math/trunc (/ r 2))
                               (math/trunc (/ (safe-len messages) 2)))
          message-cols (map | (- (math/trunc (/ c 2))
                                 (math/trunc (/ (safe-len $) 2))) messages)
          pads (map | (string/repeat " " (- $ (if (editor-state :linenumbers) 4 2)))
                    message-cols)]
      (each i (range (safe-len messages))
            (update rows (+ message-start-row i)
                    | (string $ (pads i)
                              (messages i))))
      rows)
    rows))

(defn trim-to-width [rows]
  (let [cols (- (editor-state :screencols) 1 (get-margin))]
    (map |(if (> (safe-len $) cols)
             (string/slice $ 0 cols) $) rows)))

(defn render-tabs [rows]
  (let [tabsize (get-in editor-state [:userconfig :tabsize])
        spaces (string/repeat " " tabsize)]
    (map |(string/replace-all "\t" spaces $) rows)))

(defn slice-rows [rows]
  (let [start (min (safe-len rows)
                   (editor-state :rowoffset))
        end (min (safe-len rows)
                 (+ (editor-state :rowoffset)
                    (editor-state :screenrows)))]
    (array/slice rows start end)))

(defn apply-h-scroll [rows]
  (map |(string/slice $ 
         (min (safe-len $)
              (editor-state :coloffset))) 
       rows))

(defn offset-cursor []
  (let [margin (get-margin)]
    (edup :cx | (+ $ margin))))

(defn make-row-numbers [n &opt start-n]
  (default start-n 1)
  (let [high-n (+ n start-n)
        margin (max 3 (safe-len (string high-n)))]
    (edset :leftmargin (inc margin))
    (if (editor-state :linenumbers)
      (map | (string/format (string "%" margin "s ") (string $))
           (range start-n high-n))
      (map (fn [_] " ") (range n)))))

(defn add-line-numbers [rows]
  (let [r (editor-state :screenrows)
        offset (editor-state :rowoffset)
        rownums (make-row-numbers r (inc offset))] 
    (zipwith string rownums rows)))

(defn add-relative-numbers [rows]
  # TODO: Implement relative line numbers
  rows)

(defn apply-margin [rows]
  (let [numtype (get-in editor-state [:userconfig :numtype])]
    (case numtype
      :on (add-line-numbers rows)
      :relative (add-relative-numbers rows)
      :off rows)))

(defn fill-empty-rows [rows]
  (let [r (range (editor-state :screenrows))
        fill (map (fn [_] (string (color "~" :blue))) r)] 
    (fuse-over rows fill)))

(defn add-status-bar [rows]
  (let [leftpad (string/repeat " " (get-margin))
        filename (editor-state :filename)
        cursor-pos (string (inc (abs-y)) ":" (abs-x))
        midpad (string/repeat " " (- (editor-state :screencols)
                                  ;(map safe-len [filename cursor-pos leftpad])
                                     2))
        filenamef (string "\e[1;4m" filename "\e[m"
                          (if (> (editor-state :dirty) 0) "*" ""))
        statusmsg (if (< (- (os/time) (editor-state :statusmsgtime)) 5)
                    (editor-state :statusmsg) "")
        modalmsg (cond (not (= statusmsg "")) ""
                       (= (editor-state :modalmsg) "") ""
                       (string (editor-state :modalmsg) " > "))
        modalinput (editor-state :modalinput)]
    (array/push rows (string leftpad filenamef midpad cursor-pos))
    (array/push rows (string leftpad statusmsg modalmsg modalinput))))

(defn join-rows [rows]
  (as-> (string/join rows (string (esc "K") "\r\n")) m
        (string m (esc "K"))))

(defn editor-update-rows []
  (->> (array/slice (editor-state :erows))
       (render-tabs)
       (slice-rows)
       (apply-h-scroll)
       (trim-to-width)
       (add-syntax-hl)
       (fill-empty-rows)
       (add-welcome-message)
       (apply-margin)
       (add-status-bar)
       (join-rows)))

(defn editor-refresh-screen [& opts]
  (update-screen-sizes)
  (unless (index-of :modal opts) (editor-scroll))
  (var abuf @"")

  (buffer/push-string abuf (esc "?25l"))
  (buffer/push-string abuf (esc "H"))

  (buffer/push-string abuf (editor-update-rows))

  (buffer/push-string abuf (string/format (esc "%d;%dH")
                                          (inc (editor-state :cy))
                                          (+ 1 (get-margin)
                                               (editor-state :cx))))

  (buffer/push-string abuf (esc "?25h")) 

  (file/write stdout abuf)
  (file/flush stdout))

### Input ###

(defn handle-out-of-bounds []
  #If erows is empty, insert an empty string
  (when (= 0 (safe-len (editor-state :erows)))
    (array/push (editor-state :erows) ""))
  #If cursor lower than last erow, move up to last erow
  (when (> (inc (abs-y)) (safe-len (editor-state :erows)))
    #Move viewport
    (when (> (editor-state :rowoffset) (safe-len (editor-state :erows)))
      (edset :rowoffset (max 0 (- (safe-len (editor-state :erows))
                                  (math/trunc (/ (editor-state
                                                  :screenrows) 2))))))
    #Move cursor
    (edset :cy (dec (- (safe-len (editor-state :erows))
                       (editor-state :rowoffset))))
    (edset :cx (max-x (abs-y)))))

(defn editor-handle-typing [key]
  (handle-out-of-bounds)
  (let [char (string/format "%c" key)]
    (update-erow (abs-y) | (string/insert $ (abs-x) char))
    (move-cursor :right)))

(defn carriage-return []
  (handle-out-of-bounds)
  (let [last-line (string/slice ((editor-state :erows) (abs-y)) (abs-x))
        next-line (string/slice ((editor-state :erows) (abs-y)) 0 (abs-x))]
    (update-erow (abs-y)  (fn [_] last-line))
    (edup :erows |(array/insert $ (abs-y) next-line))
    (wrap-to-start-of-next-line)))

(defn delete-char [direction]
  (when (= direction :backspace)
    (move-cursor :left))
  (update-erow (abs-y) | (string/cut $ (abs-x))))

(defn backspace-back-to-prev-line []
  (let [current-line (get-in editor-state [:erows (abs-y)])
        leaving-y (abs-y)]
    (move-cursor :up)
    (move-cursor :end) 
    # drop line being left
    (edup :erows |(array/remove $ leaving-y))
    # append current-line to new line
    (update-erow (abs-y) | (string $ current-line))))

(defn delete-next-line-up []
  (unless (= (abs-y) (safe-len (editor-state :erows)))
    (let [next-line (get-in editor-state [:erows (inc (abs-y))])]
      (update-erow (abs-y) |(string $ next-line))
      (edup :erows |(array/remove $ (inc (abs-y)))))))

# Declaring out of order to allow type checking to pass
(varfn exit-editor [])
(varfn save-file [])
(varfn save-file-as [])
(varfn load-file-modal [])
(varfn close-file [])
(varfn find-in-text-modal [])

(defn editor-process-keypress [&opt in-key]
  (let [key (or in-key (read-key)) #Blocks here waiting on keystroke
        cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)]
    (case (get keymap key key)
      (ctrl-key (chr "q")) (exit-editor)
      (ctrl-key (chr "n")) (toggle-line-numbers)
      (ctrl-key (chr "l")) (load-file-modal)
      (ctrl-key (chr "s")) (save-file) 
      (ctrl-key (chr "a")) (save-file-as) 
      (ctrl-key (chr "w")) (close-file)
      (ctrl-key (chr "f")) (find-in-text-modal)
      (ctrl-key (chr "z")) (break) # TODO: Undo in normal typing
      (ctrl-key (chr "y")) (break) # TODO: Redo in normal typing

      # If on home page of file
      :pageup (if (= 0 v-offset)
                (do (move-cursor :home)
                    (edset :cy 0))
                (move-viewport :pageup))
      :pagedown (move-viewport :pagedown)

      :home (move-cursor :home)
      :end (move-cursor :end)

      # TODO: Implement smarter tab stops
      :tab (repeat 4 (editor-handle-typing 32))

      # If cursor at margin and viewport at far left
      :leftarrow (do (if (= (abs-x) 0)
                       (wrap-to-end-of-prev-line)
                       (move-cursor :left))
                     (edset :rememberx 0))

      # If cursor at end of current line, accounting for horizontal scrolling
      :rightarrow (do (if (= (abs-x) (rowlen (abs-y)))
                        (wrap-to-start-of-next-line)
                        (move-cursor :right))
                      (edset :rememberx 0))

      # If on top row of file
      :uparrow (do (if (= (abs-y) 0)
                     (move-cursor :home)
                     (move-cursor-with-mem :up))
                   (update-x-memory cx))

      :downarrow (do (move-cursor-with-mem :down)
                (update-x-memory cx))
      
      # TODO: Ctrl + arrows
      :ctrlleftarrow (break)
      :ctrlrightarrow (break)
      :ctrluparrow (break)
      :ctrldownarrow (break)
      
      # TODO: Shift + arrows
      :shiftleftarrow (break)
      :shiftrightarrow (break)
      :shiftuparrow (break)
      :shiftdownarrow (break)
      
      :enter (carriage-return)

      # TODO: Escape

      :backspace (cond
                   #On top line and home row of file; do nothing
                   (and (= (abs-x) 0) (= (abs-y) 0)) (break)
                   #Cursor below last file line; cursor up
                   (> (abs-y) (dec (safe-len (editor-state :erows)))) (move-cursor :up)
                   #Cursor at margin and viewport far left
                   (= (abs-x) 0) (backspace-back-to-prev-line)
                   #Otherwise
                   (delete-char :backspace))

      :del (cond 
             # On last line and end of row of file; do nothing
             (and (= (abs-x) (rowlen (abs-y)))
                  (= (abs-y) (dec (safe-len (editor-state :erows))))) (break)
             # Cursor at end of current line
             (= cx (- (rowlen cy) h-offset)) (delete-next-line-up) 
             # Cursor below last file line; cursor up
             (> (abs-y) (safe-len (editor-state :erows))) (break)
             # Otherwise
             (delete-char :delete))

      # TODO: Function row

      # Default 
      (editor-handle-typing key))))

### Modals ###

(var modal-active false)

(var modal-cancel false)

(defn delete-char-modal [direction]
  (let [mx (- (abs-x) (safe-len (editor-state :modalmsg)) 4)]
    (when (= direction :backspace)
      (move-cursor :left))
    (update-minput | (string/cut $ mx))))

(defn modal-home []
  (+ (safe-len (editor-state :modalmsg)) 3))

(defn move-cursor-modal [direction]
  (case direction
    :home (edset :cx (modal-home))
    :end (edset :cx (+ (modal-home)
                       (safe-len (editor-state :modalinput))))))

(defn modal-handle-typing [key]
  (let [char (string/format "%c" key)
        mx (- (editor-state :cx) (modal-home))]
    (update-minput |(string/insert $ mx char))
    (move-cursor :right)))

(defn modal-process-keypress [kind] 
  (let [key (read-key)
        at-home (= (editor-state :cx) (modal-home))
        at-end (= (editor-state :cx) 
                  (+ (modal-home)
                     (safe-len (editor-state :modalinput))))]
    (case (get keymap key key)
      (ctrl-key (chr "q")) (set modal-cancel true)
      (ctrl-key (chr "n")) (break) 
      (ctrl-key (chr "l")) (break) 
      (ctrl-key (chr "s")) (break) 
      (ctrl-key (chr "w")) (break) 
      (ctrl-key (chr "f")) (break) 
      (ctrl-key (chr "z")) (break) # TODO: Undo in modals 
      (ctrl-key (chr "y")) (break) # TODO: Redo in modals
      
      :enter (set modal-active false)

      # BUG: This is broken when backspacing at end of current line
      :backspace (cond at-home (break)
                       (delete-char-modal :backspace))
      :del (cond at-end (break)
                 (delete-char-modal :delete))

      :pageup (move-cursor-modal :home)
      :pagedown (move-cursor-modal :end)

      # TODO: Implement autocompletion
      :tab (break)

      :uparrow (cond
                   at-home (break)
                   (move-cursor :left))
      :downarrow (cond
                    at-end (break)
                    (move-cursor :right))
      :leftarrow (cond
                   at-home (break)
                   (move-cursor :left))
      :rightarrow (cond
                    at-end (break)
                    (move-cursor :right))

      # TODO: Implement these
      :ctrluparrow (break)
      :ctrldownarrow (break)
      :ctrlleftarrow (break)
      :ctrlrightarrow (break)
      
      # TODO: Shift + arrows
      :shiftleftarrow (break)
      :shiftrightarrow (break)
      :shiftuparrow (break)
      :shiftdownarrow (break)

      :home (move-cursor-modal :home)
      :end (move-cursor-modal :end)

      :esc (set modal-cancel true)
      
      (modal-handle-typing key))))

(defn modal [message kind callback &named modalendput return-home]
  (default return-home true)
  (let [ret-x (editor-state :cx)
        ret-y (editor-state :cy)]

    #Init modal-related state
    (edset :statusmsg ""
           :modalinput ""
           :modalmsg message)
    #Two separate calls to edset because (modal-home) depends
    #on :modalmsg, so first call needs to commit before second
    #runs correctly
    (edset :cx (modal-home))
    (edset :cy (+ (editor-state :screenrows) 2))

    (set modal-active true)
    (set modal-cancel false)
    (while (and modal-active (not modal-cancel))
      (editor-refresh-screen :modal)
      (modal-process-keypress kind))

    (unless modal-cancel (callback))

    # Clean up modal-related state

    (edset :modalmsg ""
           :modalinput (or modalendput ""))
    (when return-home
      (edset :cx ret-x
             :cy ret-y))))

### File I/O ###

(defn load-file [filename]
  (let [erows (string/split "\n" (try (slurp filename) 
                                      ([e f] (spit filename "")
                                             (slurp filename))))]
    (edset :filename filename
           :erows erows)))

(defn ask-filename-modal []
  (modal "Filename?" :input |(edset :filename (editor-state :modalinput))))

(varfn save-file [] 
  (when (= "" (editor-state :filename)) (ask-filename-modal)) 
  (spit (editor-state :filename) (string/join (editor-state :erows) "\n"))
  (edset :dirty 0) 
  (send-status-msg (string "File saved!"))
  true)

(varfn save-file-as [] 
   (ask-filename-modal)
   (unless modal-cancel
           (spit (editor-state :filename) (string/join (editor-state :erows) "\n"))
           (edset :dirty 0)
           (send-status-msg (string "File saved!"))))

(varfn load-file-modal []
  (modal "Load what file?" :input |(load-file (editor-state :modalinput))) 
  (if modal-cancel
    (send-status-msg "Cancelled.")
    (send-status-msg (string "Loaded file: " (editor-state :filename)))))

(defn editor-open [args]
  (when-let [file (first (drop 1 args))]
    (load-file file)
    (send-status-msg "Tip: Ctrl + Q = quit")))

### Search ###

(defn init-find []
  (edset :tempx (editor-state :cx)
         :tempy (editor-state :cy)
         :temp-rowoffset (editor-state :rowoffset)
         :temp-coloffset (editor-state :coloffset)))

(defn exit-find []
  (edset :tempx nil
         :tempy nil
         :temp-rowoffset nil
         :temp-coloffset nil
         :search-results nil))

(defn move-to-match []
  (assert (> (safe-len (editor-state :search-results)) 0)) 
  #Search rest of current row
  (let [all-results (editor-state :search-results)
        filter-fn (fn [[y x]] (or (> y (abs-y)) (and (= y (abs-y)) (> x (abs-x)))))
        next-results (sort (filter filter-fn all-results))
        [y x] (or (first next-results) (first all-results))]
    (edset :rowoffset (max 0 (- y (math/trunc (/ (editor-state :screenrows) 2))))
           :coloffset (max 0 (+ 10 (- x (editor-state :screencols)))))
    (edset :cy (- y (editor-state :rowoffset))
           :cx (- x (editor-state :coloffset)))
    (editor-refresh-screen)))

# BUG: Find currently skips first apparent result in file?
# TODO: Implement case sensitive vs insensitive search
# TODO: Implement find and replace
# TODO: Implement Regex search and Regex replace
# TODO: Incremental highlighting of search term while typing
# TODO: Jump to previous result in addition to next

(defn find-next [&opt init]
  # Record current cursor and window position to return later
  (when init
    (init-find)
    (move-to-match)) 

  (let [key (read-key)]
    (case (get keymap key key)
      :enter (do (move-to-match)
                 (find-next))
      :esc # Return to recorded cursor and window position 
      (do (edset :cx (editor-state :tempx)
                 :cy (editor-state :tempy)
                 :rowoffset (editor-state :temp-rowoffset)
                 :coloffset (editor-state :temp-coloffset))
          (exit-find)
          (editor-refresh-screen))
      
      # Otherwise
      (do (exit-find)
          # Process keypress normally
          (editor-process-keypress key)))))

(defn find-all [search-str]
  (let [finds (map | (string/find-all search-str $) (editor-state :erows))
           i-finds @[]
           _ (each i finds (array/push i-finds [(index-of i finds) i]))
           filtered (filter |(not (empty? (last $))) i-finds)
           distribute (fn [[y arr]] (map |(array y $) arr))
           final-finds (partition 2 (flatten (map distribute filtered)))]
    (if final-finds
      (edset :search-results final-finds)
      (send-status-msg "No matches found."))))

(varfn find-in-text-modal []
       (modal "Search: " :input |(do (find-all (editor-state :modalinput))
                                      (when (editor-state :search-results)
                                        (find-next true)))
              :return-home false))

### Init and main ###

# TODO: Implement user config dotfile

(defn confirm-close []
  (do (case (string/ascii-lower (editor-state :modalinput))
        "yes" (set quit true)
        "n" (send-status-msg "Tip: Ctrl + s to Save.")
        "no" (send-status-msg "Tip: Ctrl + s to Save.")
        "s" (if (save-file)
              (set quit true)
              (send-status-msg "Tip: Ctrl + s to Save."))
        "save" (if (save-file)
                 (set quit true)
                 (send-status-msg "Tip: Ctrl + s to Save."))
        (send-status-msg "Tip: Ctrl + s to Save."))))

(varfn exit-editor []
  (if (< 0 (editor-state :dirty))
    (modal "Are you sure? Unsaved changes will be lost. (yes/No/save)"
           :input
           confirm-close)
    (set quit true)))

(varfn close-file []
  (if (< 0 (editor-state :dirty))
    (modal "Are you sure? Unsaved changes will be lost. (yes/No/save)"
           :input
           confirm-close)
    (do (reset-editor-state)
      (send-status-msg "File closed."))))

(defn load-config [] 
  )

(defn init [args]
  (when (= (os/which) :linux) 
    (prin "\e[?1049h]"))
  (enable-raw-mode)
  (reset-editor-state)
  (editor-open args))

(defn exit []
  (prin "\x1b[2J")
  (prin "\x1b[H")
  (disable-raw-mode)
  (when (= (os/which) :linux)
    (prin "\e[?1049l")))

# TODO: Write function tests
# TODO: Plugins?

(defn main [& args]
  (init args)

  (while (not quit)
    (editor-refresh-screen)
    (editor-process-keypress))

  (exit))
