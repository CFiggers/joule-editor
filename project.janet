(declare-project
  :name "joule editor"
  :description "A simple terminal-based text editor written in Janet.")

(declare-executable 
  :name "joule"
  :entry "src/joule.janet"
  # :lflags ["-static"]
  :install false)