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
       @{:cx 3
         :cy 0
         :erows @[]
         :linenumbers true
         :screenrows ((get-window-size) :rows)
         :screencols ((get-window-size) :cols)})

# Terminal

(defn die [s]
  (prin "\x1b[2J")
  (prin "\x1b[H")

  (eprint s))

# Output

(defn make-row-numbers [n &opt start-n]
  (default start-n 1)
  (if (editor-state :linenumbers)
    (map | (string/format "%2s " (string $))
     (range start-n (+ n start-n)))
    (map (fn [_] " ") (range n))))

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

(defn editor-draw-rows []
  (let [sizes (get-window-size)
        r (sizes :rows)
        c (sizes :cols)]
    (as-> (range r) m
      (map (fn [_] (string "\e[0;34m" "~" "\e[0m")) m)
      (fuse-over (editor-state :erows) m)
      (zipwith string (make-row-numbers r) m)
      (welcome-message m sizes)
      (trim-to-width m c)
      (string/join m (string (esc "K") "\r\n"))
      (string m (esc "K")))))

(editor-draw-rows)

(defn editor-refresh-screen []
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
  (let [ln (editor-state :linenumbers)]
    (case key
      1000 (when (not (= (editor-state :cx) (if ln 3 1)))
             (update editor-state :cx dec))
      1001 (when (not (= (editor-state :cx)
                         (- (editor-state :screencols) 1)))
             (update editor-state :cx inc))
      1002 (when (not (= (editor-state :cy) 0))
             (update editor-state :cy dec))
      1003 (when (not (= (editor-state :cy)
                         (- (editor-state :screenrows) 1)))
             (update editor-state :cy inc)))))

(defn toggle-line-numbers []
  (let [dc (if (editor-state :linenumbers) -2 2)]
    (update editor-state :linenumbers not)
    (update editor-state :cx |(+ $ dc))))

(defn editor-process-keypress []
  (let [key (read-key)]
    (case key 
      (ctrl-key (chr "q")) (set quit true)
      (ctrl-key (chr "n")) (toggle-line-numbers)
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

(defn main [& args]
  (enable-raw-mode)
  (editor-open args)

  (while (not quit)
    (editor-refresh-screen)
    (editor-process-keypress))

  (prin "\x1b[2J")
  (prin "\x1b[H")
  (disable-raw-mode))