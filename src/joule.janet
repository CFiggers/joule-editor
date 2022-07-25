#Uncomment to use `janet-lang/spork `helper functions.
#(use spork)

### Includes ###

(use janet-termios)

### Definitions ###

(def version
  "0.0.1")

### Data ###

(var quit false)

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

### Editor State Functions ###

(defn send-status-msg [msg]
  (set (editor-state :statusmsg) msg)
  (set (editor-state :statusmsgtime) (os/time)))

(defn get-margin []
  (if (editor-state :linenumbers)
    (editor-state :leftmargin) 1))

(defn rowlen [row]
  (if-let [erow (get-in editor-state
                        [:erows
                         (+ (editor-state :rowoffset)
                            row)])]
    (safe-len erow) 
    0))

(defn max-x [row]
  (let [v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)]
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
              (+ 10 (- (rowlen (editor-state :cy))
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
  (let [row-len (rowlen (editor-state :cy))
        screen-h (- (editor-state :screencols) (get-margin))]
    (if (> row-len screen-h)
      (move-viewport :end)
      (move-viewport :home))
    (set (editor-state :cx) (max-x (editor-state :cy)))))

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
  (let [cy (editor-state :cy)
        cx (editor-state :cx)]
    (move-cursor direction)
    # Move cursor to either end of new line (if shorter)
    # or same point on line as x memory (if longer)
    (set (editor-state :cx)
         (min (max (editor-state :rememberx) cx)
              (max-x (dec cy))))))

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
  (if (deep= @[] (flatten (editor-state :erows)))
    (let [r (editor-state :screenrows)
          c (editor-state :screencols)
          message (string "Joule editor -- version " version)
          message-row (math/trunc (/ r 2))
          message-col (- (math/trunc (/ c 2))
                         (math/trunc (/ (safe-len message) 2)))
          pad (string/repeat " " (- message-col (if (editor-state :linenumbers) 4 2)))]
      (update rows message-row | (string $ pad message))) rows))

(defn trim-to-width [rows]
  (let [cols (- (editor-state :screencols) 1)]
    (map |(if (> (safe-len $) cols)
             (string/slice $ 0 cols) $) rows)))

(defn render-tabs [rows]
  (let [tabsize (get-in editor-state [:userconfig :tabsize])
        spaces (string/repeat " " tabsize)]
    (map |(string/replace-all "\t" spaces $) rows)))

(defn slice-rows [rows]
  (let [start (min (safe-len (editor-state :erows))
                   (editor-state :rowoffset))
        end (min (safe-len (editor-state :erows))
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
  (let [r (range (editor-state :screencols))
        fill (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) r)] 
    (fuse-over rows fill)))

(defn add-status-bar [rows]
  (let [leftpad (string/repeat " " (get-margin))
        filename (editor-state :filename)
        true-y (+ (editor-state :cy) (editor-state :rowoffset))
        true-x (+ (editor-state :cx) (editor-state :coloffset))
        cursor-pos (string true-y ":" true-x)
        midpad (string/repeat " " (- (editor-state :screencols)
                                  ;(map safe-len [filename cursor-pos leftpad])
                                     2))
        filenamef (string "\e[1;4m" filename "\e[m")
        statusmsg (if (< (- (os/time) (editor-state :statusmsgtime)) 5)
                    (editor-state :statusmsg) "")]
    (array/push rows (string leftpad filenamef midpad cursor-pos))
    (array/push rows (string leftpad statusmsg))))

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

(defn editor-refresh-screen []
  (update-screen-sizes)
  (editor-scroll)
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

(defn editor-handle-typing [key]
  (let [cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)]
    # (case key
    #   )
    ))

(defn editor-process-keypress []
  (let [key (read-key)
        cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)]
    (case key
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)

      # PageUp and PageDown
      # If on home page of file
      1004 (if (= 0 (editor-state :rowoffset)) 
             (do (move-cursor :home)
                 (set (editor-state :cy) 0))
             (move-viewport :pageup))
      1005 (move-viewport :pagedown)

      # Home and End
      1006 (move-cursor :home)
      1007 (move-cursor :end)

      # Left Arrow
      # If cursor at margin and viewport at far left
      1000 (do (if (and (= cx 0) (= (editor-state :coloffset) 0))
                 (wrap-to-end-of-prev-line)
                 (move-cursor :left))
               (set (editor-state :rememberx) 0))

      # Right Arrow
      # If cursor at end of current line, accounting for horizontal scrolling
      1001 (do (if (= cx (- (rowlen cy) (editor-state :coloffset)))
                 (wrap-to-start-of-next-line)
                 (move-cursor :right))
               (set (editor-state :rememberx) 0))

      # Up Arrow
      # If on top row of file
      1002 (do (if (and (= cy 0) (= (editor-state :rowoffset) 0))
                 (move-cursor :home)
                 (move-cursor-with-mem :up)) 
               (update-x-memory cx))

      # Down Arrow
      1003 (do (move-cursor-with-mem :down)
               (update-x-memory cx))
      
      # TODO: Enter

      # TODO: Escape

      # TODO: Function row

      #Default 
      (editor-handle-typing key))))

# File i/o

(defn load-file [filename]
  (let [erows (string/split "\n" (slurp filename))]
    (set (editor-state :filename) filename)
    (set (editor-state :erows) erows)))

(defn editor-open [args]
  (when-let [file (first (drop 1 args))]
    (load-file file)
    (send-status-msg "Tip: Ctrl + Q = quit")))

# Init and main

# TODO: Implement user config dotfile

# (defn load-config []
#   )

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