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

(defn editor-draw-rows []
  (let [sizes (get-window-size)
        r (sizes :rows)
        c (sizes :cols)]
    (as-> (editor-state :erows) m
      (render-tabs m)
      (array/slice m (min (length (editor-state :erows))
                          (editor-state :rowoffset)))
      (map | (string/slice $ (min (length $) (editor-state :coloffset))) m)
      (fuse-over m (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) (range r)))
      (zipwith string (make-row-numbers r (inc (editor-state :rowoffset))) m)
      (welcome-message m sizes)
      (trim-to-width m c)
      (string/join m (string (esc "K") "\r\n"))
      (string m (esc "K")))))

(comment 
  (editor-draw-rows))

# TODO: Implement scroll line buffer based on [:userconfig :scrollpadding]

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

(defn editor-move-cursor [key]
  (let [margin (if (editor-state :linenumbers)
                 (editor-state :leftmargin) 1)
        cx (editor-state :cx)
        cy (editor-state :cy)
        offset (editor-state :rowoffset)
        max-x |(+ margin (length (get-in editor-state 
                                         [:erows (+ offset $)])))]
    (case key
      #Left Arrow
      1000 (do (if (= cx margin)
                 (when (or (> cy 0) (> offset 0))
                   (update editor-state :cy dec)
                   (set (editor-state :cx) (max-x (dec cy))))
                 (update editor-state :cx dec))
               (set (editor-state :rememberx) 0)) 

      #Right Arrow
      1001 (do (if (= cx (max-x cy))
                 (do (update editor-state :cy inc)
                     (set (editor-state :cx) margin)
                     (set (editor-state :rememberx) cx))
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
  (let [dc (if (editor-state :linenumbers) -2 2)]
    (update editor-state :linenumbers not)
    (update editor-state :cx |(+ $ dc))))

(defn editor-process-keypress []
  (let [key (read-key)]
    (case key 
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)

      # TODO: Fix Pageup and Pagedown behavior
      1004 (repeat (editor-state :screenrows) (editor-move-cursor 1002))
      1005 (repeat (editor-state :screenrows) (editor-move-cursor 1003))
      
      1006 (set (editor-state :cx) 0)
      1007 (set (editor-state :cx) (- (editor-state :screencols) 1))
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