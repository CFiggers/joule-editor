(use janet-termios)

### Definitions ###

(def version
  "0.0.1")

(def keymap
  {13 :enter
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
   1012 :ctrldownarrow})

### Data ###

(var quit false)

# TODO: Implement multiple "tabs"/buffers open simultaneously

(var editor-state
     @{:cx 0
       :cy 0
       :rememberx 0
       :rowoffset 0
       :coloffset 0
       :erows @[]
       :linenumbers true
       :leftmargin 3
       :filename ""
       :statusmsg ""
       :statusmsgtime 0
       :modalmsg ""
       :modalinput ""
       :screenrows (- ((get-window-size) :rows) 2)
       :screencols ((get-window-size) :cols)
       :userconfig @{:scrollpadding 5
                     :tabsize 4
                     :indentwith :spaces
                     :numtype :on}})

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

(defn update-erow [row f]
  (update-in editor-state [:erows row] f))

(defn update-minput [f]
  (update editor-state :modalinput f))

### Editor State Functions ###

(defn send-status-msg [msg]
  (set (editor-state :statusmsg) msg)
  (set (editor-state :statusmsgtime) (os/time)))

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
  (update editor-state :linenumbers not))

### Terminal ###

(defn update-screen-sizes []
  (let [sizes (get-window-size)]
    (set (editor-state :screencols) (sizes :cols))
    (set (editor-state :screenrows) (- (sizes :rows) 2))))

### Movement ###

# TODO: Implement buffer of lines to keep at top/bottom of screen
# when scrolling up/down, based on [:userconfig :scrollpadding]

(defn move-viewport [direction]
  (case direction
    :up (update editor-state :rowoffset dec)
    :down (update editor-state :rowoffset inc)
    :left (update editor-state :coloffset dec)
    :right (update editor-state :coloffset inc)
    
    :home (set (editor-state :coloffset) 0)
    :end (set (editor-state :coloffset)
              (+ 10 (- (rowlen (abs-y))
                       (editor-state :screencols))))
    
    :pageup (set (editor-state :rowoffset)
                 (max 0 (- (editor-state :rowoffset)
                           (dec (editor-state :screenrows)))))
    :pagedown (set (editor-state :rowoffset)
                   (+ (editor-state :rowoffset)
                      (dec (editor-state :screenrows))))))

(defn move-cursor-home []
  (move-viewport :home)
  (set (editor-state :cx) 0))

(defn move-cursor-end []
  (let [row-len (rowlen (abs-y))
        screen-h (- (editor-state :screencols) (get-margin))]
    (if (> row-len screen-h)
      (move-viewport :end)
      (move-viewport :home))
    (set (editor-state :cx) (max-x (abs-y)))))

(defn move-cursor [direction]
  (case direction 
    :up (update editor-state :cy dec)
    :down (update editor-state :cy inc)
    :left (update editor-state :cx dec)
    :right (update editor-state :cx inc)
    :home (move-cursor-home)
    :end (move-cursor-end)))

(defn editor-scroll []
  (let [cx (editor-state :cx)
        cy (editor-state :cy)]
    
    # Cursor off screen Top
    (when (< cy 0) 
      (do (when (> (editor-state :rowoffset) 0) 
            (move-viewport :up))
          (set (editor-state :cy) 0)))
    
    # Cursor off screen Bottom
    (when (>= cy (editor-state :screenrows))
      (do (move-viewport :down)
          (move-cursor :up)))
    
    # Cursor off screen Left
    (when (< cx 0)
      (do (when (> (editor-state :coloffset) 0)
            (move-viewport :left))
          (set (editor-state :cx) 0)))
    
    # Cursor off screen Right
    (when (>= cx (- (editor-state :screencols) (get-margin)))
      (do (move-viewport :right)
          (update editor-state :cx dec)))))

(defn move-cursor-with-mem [direction]
  (let [currenty (abs-y)
        cx (editor-state :cx)]
    (move-cursor direction)
    # Move cursor to either end of new line (if shorter)
    # or same point on line as x memory (if longer)
    (let [f (case direction :up dec :down inc)]
      (set (editor-state :cx)
           (min (max (editor-state :rememberx) cx)
                (max-x (f currenty)))))))

(defn update-x-memory [cx]
  (when (> cx (editor-state :rememberx))
    (set (editor-state :rememberx) cx)))

(defn wrap-to-end-of-prev-line []
  (move-cursor :up)
  (move-cursor :end))

(defn wrap-to-start-of-next-line []
  (move-cursor :down)
  (move-cursor :home))

### Output ###

(defn fuse-over [priority secondary]
  (let [dup (array/slice priority)]
    (array/concat dup (drop (safe-len priority) secondary))))

(defn add-welcome-message [rows]
  (def messages @[(string "Joule editor -- version " version)
                  ""
                  "Ctrl + q                 quit"
                  "Ctrl + l                 load"
                  "Ctrl + s                 save"
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
  (let [cols (- (editor-state :screencols) 1)]
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
    (update editor-state :cx | (+ $ margin))))

(defn make-row-numbers [n &opt start-n]
  (default start-n 1)
  (let [high-n (+ n start-n)
        margin (max 3 (safe-len (string high-n)))]
    (set (editor-state :leftmargin) (inc margin))
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
        fill (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) r)] 
    (fuse-over rows fill)))

(defn add-status-bar [rows]
  (let [leftpad (string/repeat " " (get-margin))
        filename (editor-state :filename)
        cursor-pos (string (inc (abs-y)) ":" (abs-x))
        midpad (string/repeat " " (- (editor-state :screencols)
                                  ;(map safe-len [filename cursor-pos leftpad])
                                     2))
        filenamef (string "\e[1;4m" filename "\e[m")
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
       (fill-empty-rows)
       (add-welcome-message)
       (apply-margin)
       (trim-to-width)
       (add-status-bar)
       (join-rows)))

(comment 
  (safe-len (editor-update-rows)))

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
      (set (editor-state :rowoffset)
           (max 0 (- (safe-len (editor-state :erows))
                     (math/trunc (/ (editor-state :screenrows) 2))))))
    #Move cursor
    (set (editor-state :cy)
         (dec (- (safe-len (editor-state :erows))
                 (editor-state :rowoffset))))
    (set (editor-state :cx)
         (max-x (abs-y)))))

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
    (update editor-state :erows
      |(array/insert $ (abs-y) next-line))
    (wrap-to-start-of-next-line)))

(defn delete-char [direction]
  (case direction
    :last (do (update-erow (abs-y) |(string/cut $ (dec (abs-x))))
                  (move-cursor :left))
    :current (update-erow (abs-y) |(string/cut $ (abs-x)))))

(defn backspace-back-to-prev-line []
  (let [current-line (get-in editor-state [:erows (abs-y)])
        leaving-y (abs-y)]
    (move-cursor :up)
    (move-cursor :end) 
    # drop line being left
    (update editor-state :erows 
            |(array/remove $ leaving-y))
    # append current-line to new line
    (update-erow (abs-y) | (string $ current-line))))

(defn delete-next-line-up []
  (unless (= (abs-y) (safe-len (editor-state :erows)))
    (let [next-line (get-in editor-state [:erows (inc (abs-y))])]
      (update-erow (abs-y) |(string $ next-line))
      (update editor-state :erows 
              |(array/remove $ (inc (abs-y)))))))

# Declaring out of order to allow type checking to pass
(varfn save-file [])
(varfn load-file-modal [])
(varfn close-file [])

(defn editor-process-keypress []
  (let [key (read-key) #Blocks here waiting on keystroke
        cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)]
    (case (get keymap key key)
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)
      (ctrl-key (chr "l")) (load-file-modal)
      (ctrl-key (chr "s")) (save-file)
      (ctrl-key (chr "w")) (close-file)

      # If on home page of file
      :pageup (if (= 0 v-offset) 
             (do (move-cursor :home)
                 (set (editor-state :cy) 0))
             (move-viewport :pageup))
      :pagedown (move-viewport :pagedown)

      :home (move-cursor :home)
      :end (move-cursor :end)

      # If cursor at margin and viewport at far left
      :leftarrow (do (if (= (abs-x) 0)
                 (wrap-to-end-of-prev-line)
                 (move-cursor :left))
               (set (editor-state :rememberx) 0))

      # If cursor at end of current line, accounting for horizontal scrolling
      :rightarrow (do (if (= (abs-x) (rowlen (abs-y)))
                 (wrap-to-start-of-next-line)
                 (move-cursor :right))
               (set (editor-state :rememberx) 0))

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
                   (delete-char :last))

      :del (cond 
             # On last line and end of row of file; do nothing
             (and (= (abs-x) (rowlen (abs-y)))
                  (= (abs-y) (dec (safe-len (editor-state :erows))))) (break)
             # Cursor at end of current line
             (= cx (- (rowlen cy) h-offset)) (delete-next-line-up) 
             # Cursor below last file line; cursor up
             (> (abs-x) (safe-len (editor-state :erows))) (break)
             # Otherwise
             (delete-char :current))

      # TODO: Function row

      # Default 
      (editor-handle-typing key))))

### Modals ###

(var modal-active false)

(var modal-cancel false)

(defn delete-char-modal [direction]
  (let [mx (- (abs-x) (safe-len (editor-state :modalmsg)) 3)]
    (case direction
      :last (do (update-minput | (string/cut $ (dec mx)))
                (move-cursor :left))
      :current (update-minput | (string/cut $ mx)))))

(defn modal-home []
  (+ (safe-len (editor-state :modalmsg)) 3))

(defn move-cursor-modal [direction]
  (case direction
    :home (set (editor-state :cx) modal-home)
    :end (set (editor-state :cx) (+ modal-home (editor-state :modalinput)))))

(defn modal-handle-typing [key]
  (let [char (string/format "%c" key)
        mx (- (editor-state :cx) (modal-home))]
    (update-minput |(string/insert $ mx char))
    (move-cursor :right)))

(defn modal-process-keypress [kind] 
  (let [key (read-key)]
    (case (get keymap key key)
      (ctrl-key (chr "q")) (set modal-cancel true)
      (ctrl-key (chr "n")) (break) 
      (ctrl-key (chr "l")) (break) 
      (ctrl-key (chr "s")) (break) 
      (ctrl-key (chr "w")) (break) 
      
      :enter (set modal-active false)

      :backspace (delete-char-modal :last)
      :del (delete-char-modal :current)

      :pageup (move-cursor-modal :home)
      :pagedown (move-cursor-modal :end)

      :uparrow (move-cursor :left)
      :downarrow (move-cursor :right)
      :leftarrow (move-cursor :left)
      :rightarrow (move-cursor :right)

      # TODO: Implement these
      :ctrluparrow (break)
      :ctrldownarrow (break)
      :ctrlleftarrow (break)
      :ctrlrightarrow (break)

      :home (move-cursor-modal :home)
      :end (move-cursor-modal :end)

      :esc (set modal-cancel true)
      
      (modal-handle-typing key))))

(defn modal [message kind callback]
  (let [ret-x (editor-state :cx)
        ret-y (editor-state :cy)]
    
    # Init modal-related state
    (set (editor-state :modalmsg) message)
    (set (editor-state :cx) (+ (safe-len (editor-state :modalmsg)) 3))
    (set (editor-state :cy) (+ (editor-state :screenrows) 2))

    (set modal-active true)
    (set modal-cancel false)
    (while (and modal-active (not modal-cancel))
      (editor-refresh-screen :modal)
      (modal-process-keypress kind))

    (unless modal-cancel (callback))

    # Clean up modal-related state

    (set (editor-state :modalmsg) "")
    (set (editor-state :modalinput) "")
    (set (editor-state :cx) ret-x)
    (set (editor-state :cy) ret-y)))

### File I/O ###

(defn load-file [filename]
  (let [erows (string/split "\n" (try (slurp filename) 
                                      ([e f] (spit filename "")
                                             (slurp filename))))]
    (set (editor-state :filename) filename)
    (set (editor-state :erows) erows)))

(varfn save-file [] 
  (spit (editor-state :filename) (string/join (editor-state :erows) "\n"))
  (send-status-msg (string "File saved!")))

(varfn load-file-modal []
  (modal "Load what file?" :input |(load-file (editor-state :modalinput))) 
  (if modal-cancel
    (send-status-msg "Cancelled.")
    (send-status-msg (string "Loaded file: " (editor-state :filename)))))

(defn editor-open [args]
  (when-let [file (first (drop 1 args))]
    (load-file file)
    (send-status-msg "Tip: Ctrl + Q = quit")))

# Init and main

# TODO: Implement user config dotfile

(varfn close-file []
  (set editor-state 
       @{:cx 0
       :cy 0
       :rememberx 0
       :rowoffset 0
       :coloffset 0
       :erows @[]
       :linenumbers true
       :leftmargin 3
       :filename ""
       :statusmsg ""
       :statusmsgtime 0
       :modalmsg ""
       :modalinput ""
       :screenrows (- ((get-window-size) :rows) 2)
       :screencols ((get-window-size) :cols)
       :userconfig @{:scrollpadding 5
                     :tabsize 4
                     :indentwith :spaces
                     :numtype :on}})
  (send-status-msg "File closed."))

(defn load-config [] 
  )

(defn init [args]
  (when (= (os/which) :linux) 
    (prin "\e[?1049h]"))
  (enable-raw-mode)
  (editor-open args))

(defn exit []
  (prin "\x1b[2J")
  (prin "\x1b[H")
  (disable-raw-mode)
  (when (= (os/which) :linux)
    (prin "\e[?1049l")))

(defn main [& args]
  (init args)

  (while (not quit)
    (editor-refresh-screen)
    (editor-process-keypress))

  (exit))
