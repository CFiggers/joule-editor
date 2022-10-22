(import jdn)

### Utility Functions ###

(defn esc [c]
  (string "\x1b[" c))

(defn ctrl-key [k]
  (band k 0x1f))

(defn safe-len [arg]
  (try (length arg) ([err fib] 0)))

(defn zipwith [f col1 col2]
  (var result @[])
  (let [n (min (safe-len col1) (safe-len col2))]
    (for i 0 n
         (array/push result (f (get col1 i) (get col2 i))))
    result))

(defn string/insert [str at & xs]
  (def at (if (= -1 at) (length str) at))
  (assert (<= at (length str)) 
          "Can't string/insert: `at` larger than `str`")
  (string
     (string/slice str 0 at)
     (string ;xs)
     (string/slice str (- (inc (- (length str) at))))))

(defn string/cut [str at &opt until]
  (default until at)
  (assert (>= at 0) "Can't string/cut: `at` is negative")
  (assert (>= until at) "Can't string/cut: `until` is less than `at`")
  (string
   (string/slice str 0 at)
   (string/slice str (- until (length str)))))

(defn save-jdn [what where &opt append]
  (default append false)
  (spit where (jdn/encode what) append))

(defn load-jdn [where]
  (jdn/decode (slurp where)))