(declare-project
  :name "joule editor"
  :description "A simple terminal-based text editor written in Janet."
  :dependencies ["https://www.github.com/CFiggers/janet-termios"])

(declare-executable 
  :name "joule"
  :entry "src/joule.janet"
  # :lflags ["-static"]
  :install false)