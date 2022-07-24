#Uncomment to use `janet-lang/spork `helper functions.
#(use spork)

# Includes

(use janet-termios)

# Definitions

(def version
  "0.0.1")

(defn esc [c]
  (string "\x1b[" c))

(defn ctrl-key [k]
  (band k 0x1f))

# Data

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
       :screenrows ((get-window-size) :rows)
       :screencols ((get-window-size) :cols)
       :userconfig @{:scrollpadding 5
                     :tabsize 4
                     :indentwith :spaces}})

# Terminal

(defn die [s]
  (prin "\x1b[2J")
  (prin "\x1b[H")

  (eprint s))

# Output

(defn make-row-numbers [n &opt start-n]
  (default start-n 1)
  (let [high-n (+ n start-n)
        margin (max 3 (length (string high-n)))]
    (set (editor-state :leftmargin) (inc margin))
    (if (editor-state :linenumbers)
      (map | (string/format (string "%" margin "s ") (string $))
           (range start-n high-n))
      (map (fn [_] " ") (range n)))))

(defn zipwith [f col1 col2]
  (var result @[])
  (let [n (min (length col1) (length col2))]
    (for i 0 n
         (array/push result (f (get col1 i) (get col2 i))))
    result))

(defn fuse-over [priority secondary]
  (let [dup (array/slice priority)]
    (array/concat dup (drop (length priority) secondary))))

(defn add-welcome-message [rows]
  (if (deep= @[] (flatten (editor-state :erows)))
    (let [r (editor-state :screenrows)
          c (editor-state :screencols)
          message (string "Joule editor -- version " version)
          message-row (math/trunc (/ r 2))
          message-col (- (math/trunc (/ c 2))
                         (math/trunc (/ (length message) 2)))
          pad (string/repeat " " (- message-col (if (editor-state :linenumbers) 4 2)))]
      (update rows message-row | (string $ pad message))) rows))

(defn trim-to-width [rows]
  (let [cols (- (editor-state :screencols) 1)]
    (map |(if (> (length $) cols)
             (string/slice $ 0 cols) $) rows)))

(defn render-tabs [rows]
  (let [tabsize (get-in editor-state [:userconfig :tabsize])
        spaces (string/repeat " " tabsize)]
    (map |(string/replace-all "\t" spaces $) rows)))

(defn slice-rows [rows]
  (let [start (min (length (editor-state :erows))
                   (editor-state :rowoffset))
        end (min (length (editor-state :erows))
                 (+ (editor-state :rowoffset)
                    (editor-state :screenrows)))]
    (array/slice rows start end)))

(defn apply-h-scroll [rows]
  (map |(string/slice $ 
         (min (length $)
              (editor-state :coloffset))) 
       rows))

(defn add-numbers [rows]
  (let [r (editor-state :screenrows)
        offset (editor-state :rowoffset)
        rownums (make-row-numbers r (inc offset))] 
    (zipwith string rownums rows)))

(defn offset-cursor []
  (let [margin (if (editor-state :linenumbers)
                 (editor-state :leftmargin) 1)]
    (update editor-state :cx |(+ $ margin))))

(defn apply-margin [rows]
  (as-> rows m
    (add-numbers m)
    (trim-to-width m)))

(defn fill-empty-rows [rows]
  (let [r (range (editor-state :screencols))
        fill (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) r)] 
    (fuse-over rows fill)))

(defn join-rows [rows]
  (as-> (string/join rows (string (esc "K") "\r\n")) m
        (string m (esc "K"))))

# BUG: Crashes at EOF
# BUG: No longer loads correctly if given no filename

(defn editor-update-rows []
  (->> (array/slice (editor-state :erows))
    (render-tabs)
    (slice-rows) 
    (apply-h-scroll)   
    (add-welcome-message)
    (apply-margin)
    (join-rows)))

(comment 
  (length (editor-update-rows)))

# TODO: Implement buffer of lines to keep at top/bottom of screen
# when scrolling up/down, based on [:userconfig :scrollpadding]

(defn rowlen [row]
  (if (and (< row 0) (= 0 (editor-state :rowoffset))) 0
      (length (get-in editor-state
                      [:erows
                       (+ (editor-state :rowoffset)
                          row)]))))

(defn max-x [row]
  (let [v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)]
    (min (- (rowlen row) h-offset)
         (editor-state :screencols))))

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
  (set (editor-state :cx) 0)
  (move-viewport :home))

(defn move-cursor-end []
  (let [row-len (rowlen (editor-state :cy))
        screen-h (editor-state :screencols)]
    (set (editor-state :cx) (max-x (editor-state :cy)))
    (if (> row-len screen-h)
      (move-viewport :end)
      (move-viewport :home))))

(defn move-cursor [direction]
  (case direction 
    :up (update editor-state :cy dec)
    :down (update editor-state :cy inc)
    :left (update editor-state :cx dec)
    :right (update editor-state :cx inc)
    :home (move-cursor-home)
    :end (move-cursor-end)))

# Input

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
    (when (>= cx (editor-state :screencols))
      (do (move-viewport :right)
          (update editor-state :cx dec)))))

(defn getmargin []
  (if (editor-state :linenumbers)
    (editor-state :leftmargin) 1))

(defn editor-refresh-screen []
  (editor-scroll)
  (var abuf @"")

  (buffer/push-string abuf (esc "?25l"))
  (buffer/push-string abuf (esc "H"))

  (buffer/push-string abuf (editor-update-rows))

  (buffer/push-string abuf (string/format (esc "%d;%dH")
                                          (inc (editor-state :cy))
                                          (+ 1 (getmargin)
                                               (editor-state :cx))))

  (buffer/push-string abuf (esc "?25h")) 

  (file/write stdout abuf)
  (file/flush stdout))

(defn move-cursor-with-mem [direction]
  (let [cy (editor-state :cy)
        cx (editor-state :cx)]
    (case direction
      :up (set (editor-state :cx)
               (min (max (editor-state :rememberx) cx)
                    (max-x (dec cy))))
      :down (set (editor-state :cx)
                 (min (max (editor-state :rememberx) cx)
                      (max-x (inc cy))))
      (move-cursor direction))))

(defn wrap-to-end-of-prev-line []
  (move-cursor :up)
  (move-cursor :end))

(defn wrap-to-start-of-next-line []
  (move-cursor :down)
  (move-cursor :home))

# TODO: Refactor this into something easier to reason about
(defn editor-move-cursor [key]
  (let [cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)]
    (case key
      #Left Arrow
      1000 (do (if (and (= cx 0) (= (editor-state :coloffset) 0))
                 (wrap-to-end-of-prev-line)
                 (move-cursor :left))
               (set (editor-state :rememberx) 0)) 

      #Right Arrow
      1001 (do (if (= cx (- (rowlen cy) (editor-state :coloffset)))
                 (wrap-to-start-of-next-line)
                 (move-cursor :right))
               (set (editor-state :rememberx) 0))

      #Up Arrow
      1002 (do (move-cursor :up)
               (when (> cy 0)
                 (set (editor-state :cx) (min (max (editor-state :rememberx) cx)
                                              (max-x (dec cy)))))
               (when (> cx (editor-state :rememberx)) 
                 (set (editor-state :rememberx) cx))) 

      #Down Arrow
      1003 (when (not (= cy (editor-state :screenrows)))
             (move-cursor :down)
             (set (editor-state :cx) (min (max (editor-state :rememberx) cx) 
                                          (max-x (inc cy))))
             (when (> cx (editor-state :rememberx)) 
                 (set (editor-state :rememberx) cx))))))

(defn toggle-line-numbers []
  (update editor-state :linenumbers not))

(defn editor-process-keypress []
  (let [key (read-key)]
    (case key 
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)

      # TODO: Fix Pageup and Pagedown behavior
      1004 (move-viewport :pageup)
      1005 (move-viewport :pagedown)
      
      1006 (do (set (editor-state :cx) 0)
               (set (editor-state :coloffset) 0))
      
      # TODO: Fix End key behavior
      1007 (do (set (editor-state :cx) (max-x (editor-state :cy))))
      (editor-move-cursor key))))

# File i/o

(defn editor-open [args]
  (when-let [file (first (drop 1 args))
             erows (string/split "\n" (slurp file))]
    (set (editor-state :erows) erows)))

# Init and main

# TODO: Implement user config dotfile

# (defn load-config []
#   )

(defn main [& args]
  (enable-raw-mode)
  (editor-open args)

  (while (not quit)
    (editor-refresh-screen)
    (editor-process-keypress))

  (prin "\x1b[2J")
  (prin "\x1b[H")
  (disable-raw-mode))