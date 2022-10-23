(declare-project
  :name "joule editor"
  :description "A simple terminal-based text editor written in Janet."
  :dependencies ["https://www.github.com/andrewchambers/janet-jdn"
                 "https://www.github.com/CFiggers/janet-termios"
                 "https://www.github.com/janet-lang/spork"])

(declare-executable 
  :name "joule"
  :entry "src/joule.janet"
  # :lflags ["-static"]
  :install false)