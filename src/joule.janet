(use janet-termios)
(import spork/path)
(import "/src/jermbox")
(use "/src/syntax-highlights")
(use "/src/utilities")

### Definitions ###

(def version
  "0.0.5")

### Data ###

(var joule-quit false)

# TODO: Implement multiple "tabs"/buffers open simultaneously

(var editor-state @{})

(defn get-user-config []
  (def user-home ((os/environ) "HOME"))
  (def joulerc-path (path/join user-home ".joulerc"))
  (if (nil? (os/stat joulerc-path))
    (let [default-config @{:scrollpadding 5
                           :tabsize 2
                           :indentwith :spaces
                           :numtype true}]
      (save-jdn default-config joulerc-path)
      default-config)
    (load-jdn joulerc-path)))

(defn reset-editor-state :tested []
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
         :select-from @{}
         :select-to @{}
         :clipboard @["Hello, there"]
         :screenrows (- ((get-window-size) :rows) 2)
         :screencols ((get-window-size) :cols)
         :userconfig @{:scrollpadding 5
                       :tabsize 2
                       :indentwith :spaces
                       :numtype :on}}))

### Editor State Functions ###

(defn abs-x []
  (+ (editor-state :cx) (editor-state :coloffset)))

(defn abs-y []
  (+ (editor-state :cy) (editor-state :rowoffset)))

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

(defn update-screen-sizes [&opt default-sizes]
  (let [sizes (or default-sizes (get-window-size))]
    (edset :screencols (sizes :cols)
           :screenrows (- (sizes :rows) 2))))

### Movement ###

# TODO: Implement buffer of lines to keep at top/bottom of screen
# when scrolling up/down, based on [:userconfig :scrollpadding]

# TODO: Implement jump to start/end of file

(defn clamp-row []
  (edset :cx (min (editor-state :cx)
                  (max-x (abs-y)))))

(defn clamp-viewport []
  (let [overhang (- (+ (editor-state :rowoffset) (editor-state :cy))
                    (dec (length (editor-state :erows))))]
    (when (pos? overhang)
      (edup :rowoffset | (- $ overhang))
      (clamp-row))))

(defn jump-to [y x]
  (edset :rowoffset (max 0 (- y (math/trunc (/ (editor-state :screenrows) 2))))
         :coloffset (max 0 (+ 10 (- x (editor-state :screencols)))))
  (edset :cy (- y (editor-state :rowoffset))
         :cx (- x (editor-state :coloffset)))
  (clamp-viewport))

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
    :pagedown (do (edset :rowoffset
                         (+ (editor-state :rowoffset)
                            (dec (editor-state :screenrows))))
                  (clamp-viewport))))

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
  
(varfn wrap-to-end-of-prev-line [])
(varfn wrap-to-start-of-next-line [])

(defn move-word [dir] 
  (if (and (= dir :left) (= (editor-state :cx) 0) (= (editor-state :cy) 0)) (break))
  (let [delims " .-_([{}])'\"\\/"
        left (case dir :left true :right false)
        [f df] (if left [string/reverse -] [identity +])
        mf (if left wrap-to-end-of-prev-line wrap-to-start-of-next-line)
        line (f (get-in editor-state [:erows (abs-y)] ""))
        x (if left (- (max-x (abs-y)) (abs-x)) (abs-x))
        s (string/slice line x)
        ls (safe-len (take-while |(index-of $ (string/bytes delims)) (string/bytes s)))
        d (peg/find ~(set ,delims) s ls)]
    (cond 
      (= (string/trim s) "") (do (mf)
                                 (move-word dir))
      (nil? d) (if left (move-cursor-home) (move-cursor-end))
      (edup :cx |(df $ d)))))

(defn move-cursor [direction]
  (case direction
    :up (edup :cy dec)
    :down (edup :cy inc)
    :left (edup :cx dec)
    :right (edup :cx inc)
    :home (move-cursor-home)
    :end (move-cursor-end)
    :word-left (move-word :left)
    :word-right (move-word :right)
    :in-place (break)))

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
    (let [f (case direction :up dec :down inc identity)]
      (edset :cx (min (max (editor-state :rememberx) cx)
                      (max-x (f currenty)))))))

(defn update-x-memory [cx]
  (when (> cx (editor-state :rememberx))
    (edset :rememberx cx)))

(varfn wrap-to-end-of-prev-line []
  (move-cursor :up)
  (move-cursor :end))

(varfn wrap-to-start-of-next-line []
  (move-cursor :down)
  (move-cursor :home))

### Syntax Highlighting ### 

# TODO: Correctly color strings across line breaks
# TODO: Janet Long strings w/ ``` syntax
# TODO: Extensible syntax highlighting schemes for different languages

(defn search-peg []
  (let [search-str (if (and (editor-state :search-active) 
                            (editor-state :modalinput))
                     ~(replace (<- ,(editor-state :modalinput)) 
                               ,| (bg-color $ :dull-blue)) 
                     -1)]
    ~{:search ,search-str
      :else (<- 1) 
      :main (some (+ :search :else))}))

(defn insert-search-highlight [str peg]
  (cond 
    (= str "") "" 
    (peg/match peg str) (string/join (peg/match peg str))
    str))

(defn insert-highlight [str]
  (if (= str "") "" 
    (string/join
     (peg/match (or (highlight-rules (editor-state :filetype))
                    ~(<- (some 1))) str))))

### Output ###

(def esc-code-peg
  (peg/compile
   ~{:esc-code (replace (<- (* "\e[" (some (+ :d ";")) "m"))
                        ,(fn [cap] [cap 0]))
     :else (replace (<- (to (+ "\e" -1))) 
                    ,(fn [cap] [cap (length cap)]))
     :main (some (+ :esc-code :else))}))


(defn hl-x [str x]
  (let [str-peg (reverse (peg/match esc-code-peg str))]
    (var in-x x)
    (var ret-x 0)
    (while (> in-x 0)
      (var next-peg (array/pop str-peg))
      (var peg-str (first next-peg))
      (var peg-val (last next-peg))
      (var next-peg-len (length peg-str))
      (if (> in-x peg-val)
        (do (set ret-x (+ ret-x next-peg-len))
            (set in-x (- in-x peg-val)))
        (do (set ret-x (+ ret-x in-x))
            (set in-x 0))))
    ret-x))

(defn add-search-hl [rows]
  (map |(insert-search-highlight $ (search-peg)) rows))

(varfn selection-active? [])

(defn add-select-hl [rows]
  (if (selection-active?)
    (let [[from-x from-y] (values (editor-state :select-from))
          [to-x to-y] (values (editor-state :select-to))]
      (cond
        (= from-y to-y)
        (do (update rows (- from-y (editor-state :rowoffset))
                    | (string/insert $ (hl-x $ to-x) "\e[0;49m"))
            (update rows (- from-y (editor-state :rowoffset))
                    | (string/insert $ (hl-x $ from-x) "\e[48;2;38;79;120m")))
        (= 2 (- to-y from-y)) 
        # TODO: Multi-line selection highlight
        (break))
      rows)
    rows))

(defn add-syntax-hl [rows]
  (map insert-highlight rows))

(defn fuse-over [priority secondary]
  (let [dup (array/slice priority)]
    (array/concat dup (drop (safe-len priority) secondary))))

(defn add-welcome-message [rows]
  (def messages @[(string "Joule editor -- version " version)])
  (def add-messages @[""
                      "Ctrl + q                 quit"
                      "Ctrl + l                 load"
                      "Ctrl + s                 save"
                      "Ctrl + a              save as"
                      "Ctrl + f               search"
                      "Ctrl + g       go (to line #)"
                      "Ctrl + c                 copy"
                      "Ctrl + p                paste"
                      "Ctrl + n       toggle numbers"])
  (if (>= (editor-state :screenrows) (+ 2 (length messages) (length add-messages)))
    (array/concat messages add-messages))
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
    (map | (if (> (safe-len $) cols)
             (string/slice $ 0 cols) $) rows)))

(defn render-tabs [rows]
  (let [tabsize (get-in editor-state [:userconfig :tabsize] "")
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
  (let [numtype (get-in editor-state [:userconfig :numtype] "")]
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
        # TODO: Handle Modal cursor position, like "M:0" at modal-home
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
       (add-search-hl)
       (add-select-hl)
       (fill-empty-rows)
       (add-welcome-message)
       (apply-margin)
       (add-status-bar)
       (join-rows)))

(defn editor-refresh-screen [&opt opts]
  (default opts {})
  (update-screen-sizes (opts :default-sizes))
  (unless (opts :modal) (editor-scroll))
  (var abuf @"")

  (buffer/push-string abuf (esc "?25l"))
  (buffer/push-string abuf (esc "H"))

  (buffer/push-string abuf (editor-update-rows))

  (buffer/push-string abuf (string/format (esc "%d;%dH")
                                          (inc (editor-state :cy))
                                          (+ 1 (get-margin)
                                               (editor-state :cx))))

  (buffer/push-string abuf (esc "?25h")) 

  (file/write (dyn :out stdout) abuf)
  (file/flush (dyn :out stdout)))

### Clipboard ###

(defn clear-clipboard []
  (edset :clipboard @[]))

(varfn clear-selection [])

(defn clip-copy-single [kind y from-x to-x]
  (let [line (string/slice (get-in editor-state [:erows y] "") from-x to-x)]
    (edup :clipboard |(array/push $ line))
    (when (= kind :cut)
      (update-erow y | (string/cut $ from-x (dec to-x)))
      (clear-selection)
      (edset :cx from-x))))

# TODO: Debug this-- almost definitely glitchy
(defn clip-copy-multi [kind]
  (let [[from-x from-y] (values (editor-state :select-from))
        [to-x to-y] (values (editor-state :select-to))]
    # Copy first line-- might be partial
    (clip-copy-single kind from-y from-x (max-x from-y))
    (when (= kind :cut)
      (update-erow from-y |(string/cut $ from-x (max-x from-y))))
    
    # Copy intermediate lines 
    (if (> (- to-y from-y) 1)
       (let [lines (array/slice (editor-state :erows)
                                (inc from-y)
                                (dec to-y))]
         (map (fn [l] (edup :clipboard | (array/push $ l))) lines)
         (when (= kind :cut)
           (map (fn [i] (edup :erows | (array/remove $ i)))
                (range (inc from-y)
                       to-y)))))

    # Copy last line-- might be partial
    (clip-copy-single kind to-y 0 to-x)
    (when (= kind :cut)
      (update-erow to-y |(string/cut $ 0 to-x)))))
    

# Kind can be :copy or :cut
(defn copy-to-clipboard [kind]
  (clear-clipboard)
  (if (= ((editor-state :select-from) :y) 
         ((editor-state :select-to) :y))
    (clip-copy-single kind (abs-y) 
                      ((editor-state :select-from) :x)
                      ((editor-state :select-to) :x))  
    (clip-copy-multi kind))
  (send-status-msg "Tip: Ctrl + p to paste."))

(varfn editor-handle-typing [])

(defn paste-clipboard []
  (map editor-handle-typing 
       (string/bytes 
        (string/join (editor-state :clipboard)))))

### Selection ###

(varfn selection-active? []
  (and (not (empty? (editor-state :select-from)))
       (not (empty? (editor-state :select-to)))))

(varfn clear-selection []
  (edset :select-from @{}
         :select-to @{}))

(defn grow-selection [dir]
  (let [start-x (abs-x)
        start-x (abs-y)]
   (case dir
     :left (do (move-cursor :left)
               (update-in editor-state [:select-from :x] dec))
     :right (do (move-cursor :right)
                (update-in editor-state [:select-to :x] inc))
     # TODO: growing selection up and down
     :up (break)
     :down (break))))

(defn shrink-selection [dir]
  (case dir 
    :left (do (move-cursor :left)
               (update-in editor-state [:select-to :x] dec))
    :right (do (move-cursor :right)
               (update-in editor-state [:select-from :x] inc)) 
    # TODO: shrinking selection up and down
    :up (break)
    :down (break)))

(defn handle-selection [dir]
  (if (selection-active?)
    
    (let [from (values (editor-state :select-from))
          to (values (editor-state :select-to))]
      (cond
        #Cursor at beginning of selection
        (deep= @[(abs-x) (abs-y)] from)
        (case dir
          :left (grow-selection dir)
          :right (shrink-selection dir)
          # TODO: Handling selection up and down
          :up (break)
          :down (break))
        #Cursor at end of selection
        (deep= @[(abs-x) (abs-y)] to)
        (case dir
          :left (shrink-selection dir)
          :right (grow-selection dir)
          # TODO: Handling selection up and down
          :up (break)
          :down (break))))
    
    (do (edset :select-from @{:x (abs-x) :y (abs-y)}
               :select-to @{:x (abs-x) :y (abs-y)})
        (grow-selection dir))))

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

(varfn editor-handle-typing [key]
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

(defn kill-row [y]
  (edup :erows |(array/remove $ y)))

(defn delete-row []
  (kill-row (abs-y))
  (move-cursor :home)
  (edup :dirty inc))

(defn backspace-back-to-prev-line []
  (let [current-line (get-in editor-state [:erows (abs-y)] "")
        leaving-y (abs-y)]
    (move-cursor :up)
    (move-cursor :end) 
    # drop line being left
    (kill-row leaving-y)
    # append current-line to new line
    (update-erow (abs-y) | (string $ current-line))))

(defn delete-next-line-up []
  (unless (= (abs-y) (safe-len (editor-state :erows)))
    (let [next-line (get-in editor-state [:erows (inc (abs-y))] "")]
      (update-erow (abs-y) |(string $ next-line))
      (edup :erows |(array/remove $ (inc (abs-y)))))))

(defn enter-debugger []
  (jermbox/shutdown-jermbox)
  
  (when (= (os/which) :linux)
    (prin "\e[?1049h"))
  (file/write (dyn :out stdout) "\e[H")
  (file/flush (dyn :out stdout))
  
  (file/write (dyn :out stdout) "Joule Debugger\n\nCurrent Editor State:\n\n")
  (file/write (dyn :out stdout) (string/format "%q" editor-state))
  (file/write (dyn :out stdout) "\n\n")
  (file/flush (dyn :out stdout))

  (debugger (fiber/current))
  
  (when (= (os/which) :linux)
    (prin "\e[?1049l"))
  
  (jermbox/init-jermbox))

# Declaring out of order to allow type checking to pass
(varfn save-file [])
(varfn save-file-as [])

(varfn load-file-modal [])
(varfn close-file [])
(varfn find-in-text-modal [])
(varfn jump-to-modal [])

(defn editor-process-keypress :tested [&opt in-key] 
  (let [key (or in-key (jermbox/read-key (dyn :ev))) #Blocks here waiting on keystroke
        cx (editor-state :cx)
        cy (editor-state :cy)
        v-offset (editor-state :rowoffset)
        h-offset (editor-state :coloffset)]
    (cond 
      (int? key) (editor-handle-typing key)
      (tuple? key) (case (first key)
                     :mouseleft (let [offset (dec (editor-state :leftmargin))
                                      click-y (in key 2)
                                      click-x (min (max-x (+ click-y v-offset))
                                                   (- (in key 1) offset))]
                                  (edset :cx click-x)
                                  (edset :cy click-y))
                     
                     (break))
      (case key 
          :ctrl-q (close-file :quit)
          :ctrl-n (toggle-line-numbers)
          :ctrl-l (load-file-modal)
          :ctrl-s (save-file) 
          :ctrl-a (save-file-as) 
          :ctrl-d (enter-debugger) 
          :ctrl-w (close-file :close)
          :ctrl-f (find-in-text-modal)
          :ctrl-g (jump-to-modal)
          :ctrl-z (send-status-msg "Apologies! Undo and redo are not implemented yet.") # TODO: Undo in normal typing
          :ctrl-y (send-status-msg "Apologies! Undo and redo are not implemented yet.") # TODO: Redo in normal typing
          
          :ctrl-c (copy-to-clipboard :copy)
          :ctrl-x (copy-to-clipboard :cut)
          :ctrl-v (paste-clipboard)
          :ctrl-p (paste-clipboard)
    
          # If on home page of file
          :pageup (if (= 0 v-offset)
                    (do (move-cursor :home)
                        (edset :cy 0))
                    (move-viewport :pageup))
          
          # If bottom line of file on current screen
          :pagedown (if (< (+ (abs-y) (- (editor-state :screenrows) 2)) (safe-len (editor-state :erows)))
                      (move-viewport :pagedown)
                      (do (edset :cy (- (safe-len (editor-state :erows)) (editor-state :rowoffset) 1))
                          (edset :cx (max-x (abs-y)))))
    
          :home (do (edset :rememberx 0)
                    (move-cursor :home))
          :end (do (edset :rememberx 0) 
                   (move-cursor :end))
    
          # TODO: Implement smarter tab stops
          :tab (repeat 4 (editor-handle-typing 32))
    
          # If cursor at margin and viewport at far left
          :leftarrow (do (when (selection-active?) (clear-selection))
                         (if (= (abs-x) 0)
                           (wrap-to-end-of-prev-line)
                           (move-cursor :left))
                         (edset :rememberx 0))
    
          # If cursor at end of current line, accounting for horizontal scrolling
          :rightarrow (do (when (selection-active?) (clear-selection))
                          (if (= (abs-x) (rowlen (abs-y)))
                            (wrap-to-start-of-next-line)
                            (move-cursor :right))
                          (edset :rememberx 0))
    
          # If on top row of file
          :uparrow (do (when (selection-active?) (clear-selection))
                       (if (= (abs-y) 0)
                         (move-cursor :home)
                         (move-cursor-with-mem :up))
                       (update-x-memory cx))
    
          :downarrow (do (when (selection-active?) (clear-selection))
                         (move-cursor-with-mem :down)
                         (update-x-memory cx))
          
          :ctrlleftarrow (do (edset :rememberx 0) 
                             (move-cursor :word-left))
          :ctrlrightarrow (do (edset :rememberx 0) 
                              (move-cursor :word-right))
          
          # TODO: Multiple cursors?
          # :ctrluparrow (break)
          # :ctrldownarrow (break)
          
          :shiftleftarrow (do (edset :rememberx 0)
                              (if (= (abs-x) 0)
                                (break)
                                (handle-selection :left)))
          :shiftrightarrow (do (edset :rememberx 0)
                               (if (= (abs-x) (rowlen (abs-y)))
                                 (break)
                                 (handle-selection :right)))
          
          # TODO: Shift + Ctrl + Arrows
          # :ctrlshiftuparrow (break)
          # :ctrlshiftdownarrow (break)
          # :ctrlshiftrightarrow (break)
          # :ctrlshiftleftarrow (break)
    
          # TODO: Handling selection up and down
          :shiftuparrow (send-status-msg "Apologies! Selection of multiple lines is not implemented yet.")
          :shiftdownarrow (send-status-msg "Apologies! Selection of multiple lines is not implemented yet.")
    
          :shiftdel (delete-row)
          
          :enter (carriage-return)
    
          :esc (when (selection-active?) (clear-selection))
    
          :backspace (do (edset :rememberx 0)
                         (cond
                           #On top line and home row of file; do nothing
                           (and (= (abs-x) 0) (= (abs-y) 0)) (break)
                           #Cursor below last file line; cursor up
                           (> (abs-y) (dec (safe-len (editor-state :erows)))) (move-cursor :up)
                           #Cursor at margin and viewport far left
                           (= (abs-x) 0) (backspace-back-to-prev-line)
                           #Otherwise 
                           (delete-char :backspace)))
    
          :delete (do (edset :rememberx 0)
                      (cond
                        #On last line and end of row of file; do nothing
                        (and (= (abs-x) (rowlen (abs-y)))
                             (= (abs-y) (dec (safe-len (editor-state :erows))))) (break)
                        #Cursor at end of current line
                        (= cx (- (rowlen cy) h-offset)) (delete-next-line-up)
                        #Cursor below last file line; cursor up
                        (> (abs-y) (safe-len (editor-state :erows))) (break)
                        #Otherwise
                         (delete-char :delete)))
    
          # TODO: Process mouse clicks 
          # :mouseleft (break)
          # :mouseright (break)
          # :mousemiddle (break)
          # :mouserelease (break)

          :mousewheelup (unless (= 0 (editor-state :rowoffset)) 
                                (edup :rowoffset dec) 
                                (move-cursor-with-mem :in-place)
                                (update-x-memory cx))
          :mousewheeldown (do (edup :rowoffset inc)
                              (move-cursor-with-mem :in-place)
                              (update-x-memory cx))
          
          # :windowresize (break)

          # TODO: Function row
    
          # Default 
          (break)))))

### Modals ###

(var modal-active false)

(var modal-cancel false)

(var modal-rethome true)

(defn delete-char-modal [direction]
  (let [mx (- (abs-x) (safe-len (editor-state :modalmsg)) 4)]
    (when (= direction :backspace)
      (move-cursor :left))
    (update-minput | (string/cut $ mx))))

(defn set-temp-pos []
  (edset :tempx (editor-state :cx)
         :tempy (editor-state :cy)
         :temp-rowoffset (editor-state :rowoffset)
         :temp-coloffset (editor-state :coloffset)))

(defn return-to-temp-pos []
  (edset :cx (or (editor-state :tempx) 0)
         :cy (or (editor-state :tempy) 0)
         :rowoffset (or (editor-state :temp-rowoffset) (editor-state :rowoffset))
         :coloffset (or (editor-state :temp-coloffset) (editor-state :coloffset))))

(defn clear-temp-pos []
  (edset :tempx nil
         :tempy nil
         :temp-rowoffset nil
         :temp-coloffset nil))

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

# TODO: Consolidate modal-process-keypress into editor-process-keypress?

(defn modal-process-keypress [kind] 
  (let [key (jermbox/read-key (dyn :ev))
        at-home (= (editor-state :cx) (modal-home))
        at-end (= (editor-state :cx)
                  (+ (modal-home)
                     (safe-len (editor-state :modalinput))))]
    (cond 
      (int? key) (modal-handle-typing key)
      (tuple? key) (if (= (first key) :mouseleft)
                         (set modal-cancel true)
                         (break))
      (case key
        :ctrl-q (set modal-cancel true) 
        :ctrl-n (break) 
        :ctrl-l (break) 
        :ctrl-s (break) 
        :ctrl-d (enter-debugger)
        :ctrl-w (break) 
        :ctrl-f (break) 
        :ctrl-z (break) # TODO: Undo in modals 
        :ctrl-y (break) # TODO: Redo in modals
      
        :enter (set modal-active false)

        # BUG: This is broken when backspacing at end of current line
        :backspace (cond at-home (break)
                         (delete-char-modal :backspace))
        :delete (cond at-end (break)
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

        :shiftdel (break)

        :home (move-cursor-modal :home)
        :end (move-cursor-modal :end)

        :esc (set modal-cancel true)
      
        (break)))))

(defn modal [message kind callback &named keep-input fake-text]
  (log "Ping! modal" :dump fake-text)
  (when modal-rethome
    (log "modal Saved temp pos")
    (set-temp-pos))

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
  (if fake-text
    (do (set modal-active false)
        (edset :modalinput fake-text))
    (while (and modal-active (not modal-cancel))
      (editor-refresh-screen {:modal true})
      (modal-process-keypress kind)))

  (log "Mid-modal, before callback: " :dump editor-state)

  (unless modal-cancel (callback))
  (log "Mid-modal, after callback: " :dump editor-state)

  #Clean up modal-related state

  (edset :modalmsg "")
  (unless keep-input
          (edset :modalinput ""))
  (when modal-rethome
    (return-to-temp-pos)
    (clear-temp-pos))
  (unless modal-rethome
          (set modal-rethome true))
  (log "Final state of modal: " :dump editor-state))

### File I/O ###

(defn detect-filetype [filename]
  (if-let [filen (string/split "." filename)]
    (case (last filen)
      "janet" :janet
      "c" :c
      "md" :md
      :txt)
    :txt))

(varfn confirm-lose-changes [])

(defn load-file :tested [filename &named fake-text]
  (let [erows (string/split "\n" (try (slurp filename)
                                      ([e f] (spit filename "")
                                             (slurp filename))))
        callback | (edset :filename filename
                          :erows erows
                          :filetype (detect-filetype filename))]
    (confirm-lose-changes callback :fake-text fake-text)))

(defn ask-filename-modal [&named fake-text]
  (modal "Filename?" :input |(edset :filename (editor-state :modalinput)) :fake-text fake-text))

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

(varfn load-file-modal [&opt fake-text] 
       (log "Ping! load-file-modal " :dump fake-text)
       (let [callback | (do (load-file (editor-state :modalinput)))]
         (modal "Load what file?" :input callback :fake-text fake-text)
         (if modal-cancel
           (send-status-msg "Cancelled.")
           (do (edset :cx 0 :cy 0 :rowoffset 0 :coloffset 0)
               (send-status-msg (string "Loaded file: " (editor-state :filename)))))))

(defn editor-open [args]
  (when-let [file (first (drop 1 args))]
    (load-file file)
    (send-status-msg "Tip: Ctrl + Q = quit")))

### Search ###

(defn move-to-match []
  (log "Ping! move-to-match")
  (assert (> (safe-len (editor-state :search-results)) 0)) 
  # Search rest of current row
  (let [all-results (editor-state :search-results)
        filter-fn (fn [[y x]] (or (> y (abs-y)) (and (= y (abs-y)) (> x (abs-x)))))
        next-results (sort (filter filter-fn all-results))
        [y x] (or (first next-results) (first all-results))]
    (jump-to y x)
    (editor-refresh-screen)))

# TODO: Implement case sensitive vs insensitive search
# TODO: Implement find and replace
# TODO: Implement Regex search and Regex replace
# TODO: Jump to previous result in addition to next

(defn find-next [&opt init]
  # Record current cursor and window position to return later
  (when init 
    (set-temp-pos)
    (move-to-match)) 

  (let [key (jermbox/read-key (dyn :ev))
        exit-search |(do (clear-temp-pos)
                         (edset :search-active nil))
        cancel-search |(do (return-to-temp-pos)
                           (exit-search)
                           (editor-refresh-screen))]
    (case key 
      :ctrl-q (cancel-search)
      :ctrl-d (enter-debugger)
      :ctrl-f (do (cancel-search)
                  (find-in-text-modal))

      :tab (do (move-to-match)
               (find-next))
      :enter (do (move-to-match)
                 (find-next))
      :esc (cancel-search)

      #Otherwise
       (do (exit-search)
           #Process keypress normally
           (editor-process-keypress key)))))

(defn find-all [search-str]
  (let [finds (map | (string/find-all search-str $) (editor-state :erows))
        i-finds @[]
        _ (each i finds (array/push i-finds [(index-of i finds) i]))
        filtered (filter | (not (empty? (last $))) i-finds)
        distribute (fn [[y arr]] (map | (array y $) arr))
        final-finds (partition 2 (flatten (map distribute filtered)))]
    (if final-finds
      (edset :search-results final-finds)
      (send-status-msg "No matches found."))))

(varfn find-in-text-modal [&named fake-text]
       (log "Ping! find-in-text-modal" :dump editor-state true)
       (edset :search-active true)
       (modal "Search: " :input | (find-all (editor-state :modalinput)) 
              :keep-input false :fake-text fake-text)
       (if (< 0 (safe-len (editor-state :search-results)))
         (find-next true)
         (do (edset :search-active nil)
             (send-status-msg "No matches found.")))
       (edset :modalinput ""
              :search-results nil))

### Misc Modals ### 

(varfn jump-to-modal :tested [&named fake-text] 
  (modal "Go where? (Line #)" :input
         (fn [& args]
           (if-let [n (scan-number (editor-state :modalinput))]
             (do (jump-to (dec (math/floor n)) 0)
                 (clear-temp-pos)
                 (set modal-rethome false))
             (do (return-to-temp-pos)
                 (send-status-msg "Try again."))))
         :fake-text fake-text))

### Init and main ###

# TODO: Implement user config dotfile

(varfn confirm-lose-changes [callback &named fake-text]
  (let [dispatch 
        |(do (case (string/ascii-lower (editor-state :modalinput))
                   "yes" (do (edset :dirty 0) (callback))
                   "n" (send-status-msg "Tip: Ctrl + s to Save.")
                   "no" (send-status-msg "Tip: Ctrl + s to Save.")
                   "s" (if (save-file)
                         (do (edset :dirty 0) (callback))
                         (send-status-msg "Tip: Ctrl + s to Save."))
                   "save" (if (save-file)
                            (do (edset :dirty 0) (callback))
                            (send-status-msg "Tip: Ctrl + s to Save.")))
             (send-status-msg "Tip: Ctrl + s to Save."))] 
    (if (< 0 (editor-state :dirty))
      (modal "Are you sure? Unsaved changes will be lost. (yes/No/save)"
             :input
             dispatch
             :fake-text fake-text)
      (callback))))

(varfn close-file [kind]
  (let [callback (case kind 
                   :quit |(set joule-quit true)
                   :close |(do (reset-editor-state)
                               (send-status-msg "File closed.")))]
    (set modal-rethome false)
    (confirm-lose-changes callback)))

(defn init [args]
  (jermbox/init-jermbox)

  (reset-editor-state) 
  (editor-open args))

(defn exit []
  (prin "\x1b[2J")
  (prin "\x1b[H")
  
  # TODO: Figure out how to make jermbox return to previous terminal context
  (jermbox/shutdown-jermbox)
  )

# TODO: Write function tests
# TODO: Plugins?

(defn main [& args]
  (defer (exit)
         (init args)
         (try (while (not joule-quit)
                (editor-refresh-screen)
                (editor-process-keypress))
              ([err fib]
               (propagate err fib)))))

(comment
  
  # Test Find modal
  (do (reset-editor-state)
      (load-file "project.janet")

      (move-cursor :down)
      (move-cursor :right)
      (move-cursor :right)
      (move-cursor :right)
    
      # Mimic (find-in-text-modal)
      (edset :search-active true)
      (edset :modalinput "declare")
      (set-temp-pos)

      (do (find-all (editor-state :modalinput))
          (unless (< 0 (safe-len (editor-state :search-results)))
                  (return-to-temp-pos)
                  (clear-temp-pos)
                  (set modal-rethome false)
                  (edset :search-active nil)
                  (send-status-msg "No matches found.")
                  (break))

          # Mimic (find-next true) -> (move-to-match)
          (do (let [all-results (editor-state :search-results)
                    filter-fn (fn [[y x]] (or (> y (abs-y)) (and (= y (abs-y)) (> x (abs-x)))))
                    next-results (sort (filter filter-fn all-results))
                    [y x] (or (first next-results) (first all-results))]
                (jump-to y x))))

        # Mimic local (exit-search) binding
        # (do (clear-temp-pos)
        #     (edset :search-active nil))))
          
        # Mimic local (cancel-search) binding
        (return-to-temp-pos)
        (clear-temp-pos)
        (edset :search-active nil)

        (edset :search-active true)
        (edset :modalinput "declare")
        (set-temp-pos)

        (do (find-all (editor-state :modalinput))
          (unless (< 0 (safe-len (editor-state :search-results)))
                  (return-to-temp-pos)
                  (clear-temp-pos)
                  (set modal-rethome false)
                  (edset :search-active nil)
                  (send-status-msg "No matches found.")
                  (break))

          # Mimic (find-next true) -> (move-to-match)
          (do (let [all-results (editor-state :search-results)
                    filter-fn (fn [[y x]] (or (> y (abs-y)) (and (= y (abs-y)) (> x (abs-x)))))
                    next-results (sort (filter filter-fn all-results))
                    [y x] (or (first next-results) (first all-results))]
                (jump-to y x))))
        
        # Mimic local (cancel-search) binding
        (return-to-temp-pos)
        (clear-temp-pos)
        (edset :search-active nil)  
        
        editor-state) 

  )
