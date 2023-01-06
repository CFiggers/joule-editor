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

(defn handle-selection [dir] (if (selection-active?) (let [from (values (editor-state :select-from)) to (values (editor-state :select-to))] (cond (deep= @[(abs-x) (abs-y)] from) (case dir :left (grow-selection dir) :right (shrink-selection dir) :up (break) :down (break)) (deep= @[(abs-x) (abs-y)] to) (case dir :left (shrink-selection dir) :right (grow-selection dir) :up (break) :down (break)))) (do (edset :select-from @{:x (abs-x) :y (abs-y)} :select-to @{:x (abs-x) :y (abs-y)}) (grow-selection dir))))