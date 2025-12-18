"
Utilities for code inspection and presentation.
"

(require hyrule [unless])

(import os)
(import shutil)
(import hyrule [pformat])

(import pygments [highlight])
(import pygments.lexers [get-lexer-by-name HyLexer PythonLexer PythonTracebackLexer guess-lexer])
(import pygments.formatters [TerminalFormatter])
(import pygments.styles [get-all-styles get-style-by-name])


;; Read environment variable for theme
(setv style-name (os.environ.get "HY_PYGMENTS_STYLE" "lightbulb"))
(setv bg "dark") ; default dark
(when (in ":" style_name)
  (setv [style_name bg] (.split style-name ":" 1)))
(unless (in style-name (get-all-styles))
    (setv style-name "lightbulb"))


(defn hylight [s * [bg bg] [language "hylang"] [style style_name]]
  "Syntax highlight a Hy (or other language) string.

  Keyword `bg` is \"dark\" or \"light\".
  This is used as `repl-output-fn` in `hy-repl`."
  (let [formatter (TerminalFormatter :style (get-style-by-name style-name)
                                     :bg bg
                                     :stripall True)
        term (shutil.get-terminal-size)
        lexer (get-lexer-by-name language)]
    (highlight (pformat s :indent 2 :width (- term.columns 5))
               lexer
               formatter)))

