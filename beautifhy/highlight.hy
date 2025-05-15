"
Utilities for code inspection and presentation.
"

(require beautifhy.core [defmethod])

(import hyrule [pformat])

(import pygments [highlight])
(import pygments.lexers [get-lexer-by-name HyLexer PythonLexer PythonTracebackLexer guess-lexer])
(import pygments.formatters [TerminalFormatter])


(defn hylight [s * [bg "light"] [language "hylang"]]
  "Syntax highlight a Hy (or other language) string.
  Keyword `bg` is \"dark\" or \"light\".

  This is nice for use in the repl - put
  (import beautifhy.highlight [hylight]
  (setv repl-output-fn hylight)
  in your .hyrc."
  (let [formatter (TerminalFormatter :bg bg :stripall True)
        term (shutil.get-terminal-size)
        lexer (get-lexer-by-name language)]
    (highlight (pformat s :indent 2 :width (- term.columns 5))
               (HyLexer)
               formatter)))

