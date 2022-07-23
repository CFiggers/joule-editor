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
     @{:cx 4
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

(defn welcome-message [m sizes]
  (if (deep= @[] (flatten (editor-state :erows)))
    (let [r (sizes :rows)
          c (sizes :cols)
          message (string "Joule editor -- version " version)
          message-row (math/trunc (/ r 2))
          message-col (- (math/trunc (/ c 2))
                         (math/trunc (/ (length message) 2)))
          pad (string/repeat " " (- message-col (if (editor-state :linenumbers) 4 2)))]
      (update m message-row | (string $ pad message)))
    m))

(defn trim-to-width [m c]
  (map |(if (> (length $) (- c 1)) 
          (string/slice $ 0 (- c 1))
          $) m))

(defn render-tabs [rows]
  (let [tabsize (get-in editor-state [:userconfig :tabsize])
        spaces (string/repeat " " tabsize)]
    (map |(string/replace-all "\t" spaces $) rows)))

(defn slice-rows [rows]
  (let [start (min (length (editor-state :erows))
                   (editor-state :rowoffset))
        end (min (length (editor-state :erows))
                 (+ (editor-state :rowoffset)
                    (editor-state :screencols)))]
    (array/slice rows start end)))

(defn editor-draw-rows []
  (let [sizes (get-window-size)
        r (sizes :rows)
        c (sizes :cols)]
    (as-> (editor-state :erows) m
      (render-tabs m)
      (slice-rows m)
      (map | (string/slice $ (min (length $) (editor-state :coloffset))) m)
      (fuse-over m (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) (range r)))
      (zipwith string (make-row-numbers r (inc (editor-state :rowoffset))) m)
      (welcome-message m sizes)
      (trim-to-width m c)
      (string/join m (string (esc "K") "\r\n"))
      (string m (esc "K")))))

(comment 
  (editor-draw-rows))

# TODO: Implement buffer of lines to keep at top/bottom of screen
# when scrolling up/down, based on [:userconfig :scrollpadding]

(defn editor-scroll []
  (let [cx (editor-state :cx)
        cy (editor-state :cy)
        margin (if (editor-state :linenumbers) 
                 (editor-state :leftmargin) 1)]
    
    # Cursor off screen Top
    (when (< cy 0) 
      (do (when (> (editor-state :rowoffset) 0) 
            (update editor-state :rowoffset dec))
          (set (editor-state :cy) 0)))
    
    # Cursor off screen Bottom
    (when (>= cy (editor-state :screenrows))
      (do (update editor-state :rowoffset inc)
          (update editor-state :cy dec)))
    
    # Cursor off screen Left
    (when (< cx margin)
      (do (when (> (editor-state :coloffset) 0)
            (update editor-state :coloffset dec))
          (set (editor-state :cx) margin)))
    
    # Cursor off screen Right
    (when (>= cx (editor-state :screencols))
      (do (update editor-state :coloffset inc)
          (update editor-state :cx dec)))))

(defn editor-refresh-screen []
  (editor-scroll)
  (var abuf @"")

  (buffer/push-string abuf (esc "?25l"))
  (buffer/push-string abuf (esc "H"))

  (buffer/push-string abuf (editor-draw-rows))

  (buffer/push-string abuf (string/format (esc "%d;%dH")
                                          (inc (editor-state :cy))
                                          (inc (editor-state :cx))))

  (buffer/push-string abuf (esc "?25h")) 

  (file/write stdout abuf)
  (file/flush stdout))

# Input

(defn rowlen [row]
  (length (get-in editor-state [:erows (+ (editor-state :rowoffset) 
                                          row)])))

(defn max-x [row]
  (let [margin (if (editor-state :linenumbers)
                 (editor-state :leftmargin) 1)
        v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)] 
    (min (- (+ margin (rowlen row)) h-offset) (editor-state :screencols))))

(defn wrap-to-end-of-prev-line [margin cy] 
  # Move cursor up one line
  (update editor-state :cy dec)

  # Move cursor to end of previous line, accounting for column offset
  (set (editor-state :cx) (max-x (dec cy)))

  # Update viewport if line goes off of current screen
  (when (> (rowlen (dec cy)) (editor-state :screencols))
    (set (editor-state :coloffset) 
         (- (+ (rowlen (dec cy)) margin) 
            (editor-state :screencols)))))

(defn wrap-to-start-of-next-line [margin cx]
  # Move cursor down one line
  (update editor-state :cy inc)

  # Move cursor to start of line
  (set (editor-state :cx) margin)

  # Reset viewport to zero
  (set (editor-state :coloffset) 0)
  
  # Set horizontal memory to previous cx-value
  (set (editor-state :rememberx) cx))

# TODO: Refactor this into something easier to reason about
(defn editor-move-cursor [key]
  (let [margin (if (editor-state :linenumbers)
                 (editor-state :leftmargin) 1)
        cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)]
    (case key
      #Left Arrow
      1000 (do (if (= (editor-state :coloffset) 0)
                 (if (or (> cy 0) (> v-offset 0))
                   (wrap-to-end-of-prev-line margin cy)
                   (update editor-state :cx dec))
                 (update editor-state :cx dec))
               (set (editor-state :rememberx) 0)) 

      #Right Arrow
      1001 (do (if (= cx (- (+ (rowlen cy) margin) (editor-state :coloffset)))
                 (wrap-to-start-of-next-line margin cx)
                 (when (not (= cx (editor-state :screencols)))
                   (update editor-state :cx inc)))
               (set (editor-state :rememberx) 0))

      #Up Arrow
      1002 (do (update editor-state :cy dec)
               (when (> cy 0)
                 (set (editor-state :cx) (min (max (editor-state :rememberx) cx)
                                              (max-x (dec cy)))))
               (when (> cx (editor-state :rememberx)) 
                 (set (editor-state :rememberx) cx))) 

      #Down Arrow
      1003 (when (not (= cy (editor-state :screenrows)))
             (update editor-state :cy inc)
             (set (editor-state :cx) (min (max (editor-state :rememberx) cx) 
                                          (max-x (inc cy))))
             (when (> cx (editor-state :rememberx)) 
                 (set (editor-state :rememberx) cx))))))

(defn toggle-line-numbers []
  (let [margin (dec (editor-state :leftmargin))
        dc (if (editor-state :linenumbers) (- margin) margin)]
    (update editor-state :linenumbers not)
    (update editor-state :cx |(+ $ dc))))

(defn editor-process-keypress []
  (let [key (read-key)]
    (case key 
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)

      # TODO: Fix Pageup and Pagedown behavior
      1004 (set (editor-state :rowoffset) (max 0 (- (editor-state :rowoffset)
                                                    (editor-state :screenrows))))
      1005 (update editor-state :rowoffset |(+ $ (editor-state :screenrows)))
      
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