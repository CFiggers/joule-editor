(use judge)

(import "/src/joule")
(import "/src/utilities")
(use "/test/test-utils")

(def start (os/clock))

(deftest: with-fresh-editor test-abs-x [_]
  (def editor-state joule/editor-state)
  
  (joule/load-file "misc/test-joule.janet.test")
  (test (joule/abs-x) 0) 

  (test (seq [_ :range [0 (joule/max-x (joule/editor-state :cy))]]
             (do (joule/editor-process-keypress :rightarrow)
                 (joule/abs-x))) 
        @[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19])

  (joule/jump-to 114 0)
  (joule/editor-process-keypress :end)
  (test (joule/abs-x) 507))

(deftest: with-fresh-editor test-abs-y [_]
  (def editor-state joule/editor-state)

  (joule/load-file "misc/test-joule.janet.test")
  (test (joule/abs-y) 0) 

  (let [jump-to [16 25 41 70 81 99 113 140]
        test-fn |(do (joule/jump-to $ 0) (joule/abs-y))] 
    (test (map test-fn jump-to) 
          @[16 25 41 70 81 99 113 113])))

(deftest: with-fresh-editor test-max-x [_]
  (joule/load-file "misc/test-joule.janet.test") 

  (test (seq [r :range [0 (length (joule/editor-state :erows))]] 
             (joule/max-x r)) 
        @[19 19 23 30 22 0 19 0 12 10 0 12 0 22 0 61 0 22 0 24 39 
          53 35 43 37 46 42 44 21 29 0 35 19 14 14 21 21 21 19 17 
          26 22 21 21 22 25 21 23 25 23 37 52 46 39 33 42 39 0 30 
          0 14 51 0 14 51 0 21 39 35 27 41 0 20 39 35 26 42 0 25 
          41 20 0 23 23 0 27 23 35 0 19 33 34 0 18 51 20 7 0 17 
          43 34 38 0 28 26 0 16 0 46 51 36 45 0 100]))

(deftest final-time
      (print "Elapsed time: " (- (os/clock) start) " seconds"))

