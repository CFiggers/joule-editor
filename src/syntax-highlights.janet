(use "./core-fns")

(defn color
  ```
  Return `text` surrounded by ANSI color codes corresponding to `color-key`.
  Options are:
  - :black
  - :red
  - :green
  - :yellow
  - :blue
  - :magenta
  - :cyan
  - :white
  - :brown                                          
  - :default
  ```                                               
  [text color-key]
  (if-let [color-code                               
           (case color-key
             :black "0;30" :red "0;31"              
             :green "0;32" :yellow "0;33"
             :blue "0;34" :magenta "38;2;197;134;192"
             :cyan "0;36" :white "0;37"
             :brown "38;2;206;145;120"              
             :cream-green "38;2;181;206;168"
             :powder-blue "38;2;156;220;254"
             :drab-green "38;2;106;153;85"
             :default "0;39")]
    (string "\e[" color-code "m" text "\e[0;39m")   
    text))

(defn bg-color
  [text color-key]
  (if-let [color-code
           (case color-key
             :black "0;40" :red "0;41"
             :green "0;42" :yellow "0;43"
             :blue "0;44" :magenta "0;45"
             :cyan "0;46" :white "0;47"             
             :default "0;49"
             :dull-blue "48;2;38;79;120")]          
    (string "\e[" color-code "m" text "\e[0;49m")
    text))

(def highlight-rules
  {:janet
    ~{:comment (replace (<- (* "#" (any 1))) ,|(color $ :drab-green))
      :string (replace (<- (* "\"" (to "\"") "\"")) ,|(color $ :brown))
      :ws (<- (set " \t\r\f\n\0\v"))
      :delim (+ :ws (set "([{\"`}])"))
      :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
      :numbers (replace (<- (some (+ :d "."))) ,|(color $ :cream-green))
      :keyword (replace (<- (* ":" (some :symchars))) ,|(color $ :magenta)) 
      :symbol (replace (<- (some (+ :symchars "-"))) ,|(color $ :powder-blue))
      :special (replace (* (<- (+ ,;core-fns ,;special-forms)) :ws) ,|(string (color $0 :magenta) $1))
      :else (<- 1)
      :value (+ :comment :string :numbers :keyword :special :symbol :ws :else)
      :main (some :value)}
   :c 
    ~(<- (some 1))
    # ~{:ws (<- (set " \t\r\f\n\0\v"))
    #   :else (<- 1)
    #   :value (+ :ws :else)
    #   :main (some value)}
   :md
    ~(<- (some 1)) 
    # ~{:ws (<- (set " \t\r\f\n\0\v"))
    #   :else (<- 1)
    #   :value (+ :ws :else)
    #   :main (some value)}
   :txt
    ~(<- (some 1))
    # ~{:ws (<- (set " \t\r\f\n\0\v"))
    #   :else (<- 1)
    #   :value (+ :ws :else)
    #   :main (some value)}
   })

(defn compile-highlights [lang-key]
  (peg/compile (highlight-rules lang-key)))