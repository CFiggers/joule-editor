(use "./core-fns")

(defn color
  "Return `text` surrounded by ANSI color codes corresponding to `color-key`."
  [text color-key]
  (if-let [color-code                               
           (case color-key
             :black "0;30" 
             :red "0;31"              
             :green "0;32" 
             :yellow "0;33"
             :blue "0;34"
             :medium-blue "38;2;86;156;214" 
             :magenta "38;2;197;134;192"
             :cyan "0;36" 
             :white "0;37"
             :brown "38;2;206;145;120"              
             :cream-green "38;2;181;206;168"
             :powder-blue "38;2;156;220;254"
             :rich-blue "38;2;79;193;255"
             :drab-green "38;2;106;153;85"
             :seafoam-green "38;2;78;201;176"
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

(comment 
  
  (use /src/core-fns)

  (def test-c "/* A comment */ \n static Janet \n char int long short char16_t cfun_init_event ( int32_t argc, Janet *argv) {}")

  (peg/match (highlight-rules :c) test-c)

  (def str-list ["int32_t" "long"
                 "char" "int" "long" "short" "void" "bool" "float" "double" "signed" "unsigned" "char16_t" "char16_t" "char32_t" "char8_t" "int8_t" "uint8_t" "int16_t" "uint16_t" "int32_t" "uint32_t" "int64_t" "uint64_t" "uintptr_t" "size_t"])

  (peg/match ~(some (+ (replace (* (<- (+ ,;c-types)) (<- " ")) ,(fn [a _] (string "_" a "_"))) 1)) test-c)
   
  )

(def highlight-rules
  {:janet
    ~{:comment (replace (<- (* "#" (any 1))) ,|(color $ :drab-green))
      :string (replace (<- (* "\"" (to "\"") "\"")) ,|(color $ :brown))
      :ws (<- (set " \t\r\f\n\0\v"))
      :delim (+ :ws (set "([{\"`}])"))
      :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
      :numbers (replace (<- (some (+ :d "."))) ,|(color $ :cream-green))
      :keyword (replace (<- (* ":" (some :symchars))) ,|(color $ :rich-blue)) 
      :symbol (replace (<- (some (+ :symchars "-"))) ,|(color $ :powder-blue))
      :special (replace (* (<- (+ ,;janet-core-fns ,;janet-special-forms)) :ws) ,|(string (color $0 :magenta) $1))
      :else (<- 1)
      :value (+ :comment :string :numbers :keyword :special :symbol :ws :else)
      :main (some :value)}
   :c 
    ~{:in-line-comment (replace (<- (* "//" (any 1))) ,|(color $ :drab-green))
      :block-comment (replace (<- (* "/*" (to "*/") "*/")) ,|(color $ :drab-green))
      :corefn (replace (* (<- (+ ,;c-core-fns)) :ws) ,(fn [cap ws] (string (color cap :white) ws)))
      :type1 (replace (* (<- (+ ,;c-types1)) :ws) ,(fn [cap ws] (string (color cap :seafoam-green) ws)))
      :type2 (replace (* (<- (+ ,;c-types2)) :ws) ,(fn [cap ws] (string (color cap :medium-blue) ws)))
      :ctrl-flow (replace (* (<- (+ ,;c-ctrl-flow)) :ws) ,(fn [cap ws] (string (color cap :magenta) ws)))
      :enum (replace (* (<- (at-least 3 (+ (range "AZ") "_"))) :ws) ,(fn [cap ws] (string (color cap :medium-blue) ws)))
      :string (replace (<- (* "\"" (to "\"") "\"")) ,|(color $ :brown))
      :include (replace (<- (* "<" (to ">") ">")) ,|(color $ :brown))
      :numbers (replace (<- (some (+ :d "."))) ,|(color $ :cream-green))
      :ws (<- (+ (set " \t\r\f\n\0\v;") -1))
      :else (<- 1)
      :value (+ :in-line-comment :block-comment :corefn :type1 :type2 :ctrl-flow :string :include :numbers :enum :ws :else)
      :main (some :value)}
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