(import jermbox)

(varglobal "env" (jermbox/init-event))

(defn init-jermbox []
  (jermbox/init)
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
   65513 :mousemiddle
   65512 :mouserelease
   65511 :mousewheelup
   65510 :mousewheeldown

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

(defn get-key-struct [env]
  {:key (jermbox/event-key env)
   :modifier (jermbox/event-modifier env)
   :character (jermbox/event-character env)})

(defn main-loop [env]
  (var continue true)
  (var keystrokes @[])
  (while continue
    (set keystrokes @[])
    (jermbox/poll-event env)
    (array/push keystrokes (get-key-struct env))
    (while (jermbox/peek-event env 10)
      (array/push keystrokes (get-key-struct env)))
    (when (= (first keystrokes) jermbox/key-ctrl-q)
      (set continue false))
    (set continue false))
  keystrokes)

(defn convert-single [ar]
  (let [{:key key
         :character char} ar
        value (if (= 0 key) char key)]
    (get keymap value value)))

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

(defn read-key []
  (let [jermbox-array (main-loop env)]
    (if (= 1 (length jermbox-array))
      (convert-single (first jermbox-array))
      (convert-multiple jermbox-array))))

(comment

  (jermbox/shutdown)

  (init-jermbox)

  (read-key)

  (do (init-jermbox)
      (read-key))

  )