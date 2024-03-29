(import jermbox)
(use /src/utilities)

(defn init-jermbox []
  (setdyn :ev (jermbox/init-event))
  (jermbox/init)
  (jermbox/select-input-mode (bor jermbox/input-esc jermbox/input-mouse))
  (jermbox/select-output-mode jermbox/output-256))

(defn shutdown-jermbox []
  (jermbox/shutdown))

(def keymap
  {1 :ctrl-a  2 :ctrl-b  3 :ctrl-c  4 :ctrl-d
   5 :ctrl-e  6 :ctrl-f  7 :ctrl-g  8 :ctrl-h
   9 :tab    10 :ctrl-j 11 :ctrl-k 12 :ctrl-l
   13 :enter  14 :ctrl-n 15 :ctrl-o 16 :ctrl-p
   17 :ctrl-q 18 :ctrl-r 19 :ctrl-s 20 :ctrl-t
   21 :ctrl-u 22 :ctrl-v 23 :ctrl-w 24 :ctrl-x
   25 :ctrl-y 26 :ctrl-z

   27 :esc
   127 :backspace

   65523 :insert
   65522 :delete
   65521 :home
   65520 :end
   65519 :pageup
   65518 :pagedown
   65517 :uparrow
   65516 :downarrow
   65515 :leftarrow
   65514 :rightarrow
   65513 :mouseleft
   65512 :mouseright
   65511 :mousemiddle
   65510 :mouserelease
   65509 :mousewheelup
   65508 :mousewheeldown

   #1009 :ctrlleftarrow
   #1010 :ctrlrightarrow
   #1011 :ctrluparrow
   #1012 :ctrldownarrow
   #1013 :shiftleftarrow
   #1014 :shiftrightarrow
   #1015 :shiftuparrow
   #1016 :shiftdownarrow
   #1017 :shiftdel
   
   })

(defn get-key-struct [event]
  {:key (jermbox/event-key event)
   :modifier (jermbox/event-modifier event)
   :character (jermbox/event-character event)
   :x (jermbox/event-x event)
   :y (jermbox/event-y event)
   :width (jermbox/event-width event)
   :height (jermbox/event-height event)})

(defn main-loop [event]
  (var keystrokes @[]) 
  (jermbox/poll-event event)
  (array/push keystrokes (get-key-struct event))
  (when (deep= keystrokes @[{:character 0 :key 27 :modifier 0 :x 0 :y 0 :width 0 :height 0}])
    (while (jermbox/peek-event event 1)
      (array/push keystrokes (get-key-struct event))))
  keystrokes)

(defn convert-single [ar] 
  (let [{:key key
         :character char
         :x x
         :y y
         :width width
         :height height} ar]
    (cond 
      (= key 65513) [:mouseleft x y]
      (or (not= 0 width) (not= 0 height)) :windowresize
      (let [value (if (= 0 key) char key)] 
        (get keymap value value)))))

(defn convert-multiple [ar]
  (case ((get ar 4) :character)
    50 (case ((get ar 5) :character)
         65 :shiftuparrow
         66 :shiftdownarrow
         67 :shiftrightarrow
         68 :shiftleftarrow
         126 :shiftdel)
    53 (case ((get ar 5) :character)
         65 :ctrluparrow
         66 :ctrldownarrow
         67 :ctrlrightarrow
         68 :ctrlleftarrow)
    54 (case ((get ar 5) :character)
         65 :ctrlshiftuparrow
         66 :ctrlshiftdownarrow
         67 :ctrlshiftrightarrow
         68 :ctrlshiftleftarrow)))

(defn read-key [event]
  (let [jermbox-array (main-loop event)] 
    # (log jermbox-array)
    (if (= 1 (length jermbox-array))
      (convert-single (first jermbox-array))
      (convert-multiple jermbox-array))))

(comment

  (jermbox/shutdown)

  (init-jermbox)

  (read-key (dyn :ev))

  (main-loop (dyn :ev))

  (do (init-jermbox)
      (read-key))

  )