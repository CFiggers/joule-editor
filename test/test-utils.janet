(use judge)

(import "/src/joule")
(import "/src/utilities")

(defn default-screen-size []
  (set (joule/editor-state :screenrows) 40)
  (set (joule/editor-state :screencols) 100))

(defn render-screen []
  (with-dyns [:out (file/temp)]
    (joule/editor-refresh-screen {:default-sizes {:cols 100 :rows 40}})))

(defmacro render-screen-return-result [res &opt cols rows]
  (default cols 100)
  (default rows 40)
  (set (joule/editor-state :screenrows) rows)
  (set (joule/editor-state :screencols) cols)

  ~(with-dyns [:out (file/temp)]
        (joule/editor-refresh-screen {:default-sizes {:cols ,cols :rows ,rows}})
        (file/seek (dyn :out) :set 0)
        (set ,res (string (file/read (dyn :out) :all)))))

(deftest-type with-fresh-editor
  # Setup: Reset editor state and ignore screen size
  :setup (fn [] (joule/reset-editor-state)
                (default-screen-size))
  
  # Reset: Reset editor state and ignore screen size
  :reset (fn [_] (joule/reset-editor-state)
                 (default-screen-size)))