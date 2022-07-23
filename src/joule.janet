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
         :screenrows ((get-window-size) :rows)
         :screencols ((get-window-size) :cols)})

# Terminal

(defn die [s]
  (prin "\x1b[2J")
  (prin "\x1b[H")

  (eprint s))

# Output

(defn make-row-numbers [n]
  (map
   |(string/format "%2s" (string $))
   (range 1 (inc n))))

(defn editor-draw-rows []
  (let [sizes (get-window-size)
        message (string "JIM editor -- version " version)
        message-row (math/trunc (/ (sizes :rows) 2))
        message-col (- (math/trunc (/ (sizes :cols) 2))
                       (math/trunc (/ (length message) 2)))
        pad (string/repeat " " (- message-col 4))
        rows (update (map |(string $ " ~") (make-row-numbers (sizes :rows)))
                     message-row | (string $ pad message))]
    (string (string/join
             rows
             (string (esc "K") "\r\n"))
            (esc "K"))))

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
  (case key
    1000 (when (not (= (editor-state :cx) 0)) 
           (update editor-state :cx dec))
    1001 (when (not (= (editor-state :cx) 
                       (- (editor-state :screencols) 1))) 
           (update editor-state :cx inc))
    1002 (when (not (= (editor-state :cy) 0)) 
           (update editor-state :cy dec)) 
    1003 (when (not (= (editor-state :cy)
                       (- (editor-state :screenrows) 1)))
           (update editor-state :cy inc))))

(defn editor-process-keypress []
  (let [key (read-key)]
    (case key 
      (ctrl-key (first "q")) (set quit true)
      1004 (repeat (editor-state :screenrows) (editor-move-cursor 1002))
      1005 (repeat (editor-state :screenrows) (editor-move-cursor 1003))
      1006 (set (editor-state :cx) 0)
      1007 (set (editor-state :cx) (- (editor-state :screencols) 1))
      (editor-move-cursor key))))

# File i/o



# Init and main

(defn main [& args]
  (enable-raw-mode)

  (while (not quit)
    (editor-refresh-screen)
    (editor-process-keypress))

  (prin "\x1b[2J")
  (prin "\x1b[H")
  (disable-raw-mode))