"
beautifhy.lint - Hy linter for syntax errors and common improvement suggestions.

Rules:
- defn/fn with () parameter list instead of []
- redundant (do ...) in defn/fn/when/unless/if bodies
- (if cond (do ...)) should be (when cond ...)
- identity arithmetic: (+ x 0), (* x 1)
- (+ x 1) / (- x 1) should use inc/dec from hyrule
- old-style import syntax: (import [module [sym]])
"

(require hyrule [-> ->>])
(require beautifhy.core [defmethod])

(import hy.models [Expression List Integer String Symbol Object])
(import hy.reader [read-many])
(import hy.errors [HySyntaxError HyCompileError])
(import hy.reader.exceptions [LexException])
(import beautifhy.core [issue defn-layout])

;; * Severity levels
(setv ERROR "error")
(setv WARNING "warning")
(setv INFO "info")

;; * Constants for dispatch and comparison
(setv DEFN   (Symbol "defn"))
(setv FN     (Symbol "fn"))
(setv IF     (Symbol "if"))
(setv WHEN   (Symbol "when"))
(setv UNLESS (Symbol "unless"))
(setv DO     (Symbol "do"))
(setv PLUS   (Symbol "+"))
(setv MINUS  (Symbol "-"))
(setv STAR   (Symbol "*"))
(setv IMPORT     (Symbol "import"))
(setv QUASIQUOTE (Symbol "quasiquote"))
(setv ZERO (Integer 0))
(setv ONE  (Integer 1))

;; * Helpers
(defn has-do-body? [form param-count]
  "True if form has exactly one body expression which is a (do ...) form."
  (and (= (len form) (+ param-count 2))
       (let [body (get form (+ param-count 1))]
         (and (isinstance body Expression)
              (> (len body) 0)
              (= (get body 0) DO)))))

;; * Main lint dispatcher
;;
;; Note: Symbol inherits from both Object and str. A [#^ str] overload would
;; be ambiguous with [#^ Object] for Symbols. The source-string entry point is
;; therefore a plain function; defmethod handles model types only.

(defn lint [source]
  "Parse and lint Hy source string."
  (try
    (lint-forms (list (read-many source)))
    (except [e LexException]
      [(issue f"Lex error: {e.msg}" ERROR (or e.lineno 1) (or e.offset 0))])
    (except [e HySyntaxError]
      [(issue f"Syntax error: {e.msg}" ERROR (or e.lineno 1) (or e.colno 0))])
    (except [e HyCompileError]
      [(issue f"Compile error: {e}" ERROR 1 0)])
    (except [e Exception]
      [(issue f"Parse error: {e}" ERROR 1 0)])))

(defn lint-forms [forms]
  "Lint a list of top-level forms."
  (let [issues []]
    (for [f forms]
      (.extend issues (lint-form f)))
    issues))

(defmethod lint-form [#^ Expression form]
  "Lint a single expression and recurse into subforms."
  (let [issues []
        line   (or form.start-line 1)
        col    (or form.start-column 0)]
    (when (and form (> (len form) 0))
      (let [head (get form 0)]
        (cond
          ;; Don't lint inside quasiquote templates — they contain unquote
          ;; expressions that look like code but are data for macro expansion.
          (= head QUASIQUOTE)                 None
          (= head DEFN)                       (.extend issues (lint-defn form line col))
          (= head FN)                         (.extend issues (lint-fn form line col))
          (= head IF)                         (.extend issues (lint-if form line col))
          (in head [WHEN UNLESS])             (.extend issues (lint-when form line col))
          (= head DO)                         (.extend issues (lint-do form line col))
          (in head [PLUS MINUS STAR])         (.extend issues (lint-arithmetic form line col))
          (= head IMPORT)                     (.extend issues (lint-import form line col)))
        ;; Don't recurse into quasiquote — its children are template data, not code.
        (when (!= head QUASIQUOTE)
          (for [sub form]
            (.extend issues (lint-form sub))))))
    issues))

(defmethod lint-form [#^ Object form]
  "Atoms have no issues."
  [])

;; * Rules
(defn lint-defn [form line col]
  "Lint defn: check param list brackets, redundant do body.
  Handles both plain and decorated defn forms."
  (let [issues []
        #(name-idx params-idx) (defn-layout form)]
    (when (>= (len form) (+ params-idx 1))
      (let [params (get form params-idx)]
        (cond
          (isinstance params Expression)
            (.append issues (issue "Use [] for parameter lists, not ()" ERROR line col))
          (and (isinstance params List) (has-do-body? form params-idx))
            (.append issues (issue "(defn [...] (do ...)) — remove redundant do" INFO line col)))))
    issues))

(defn lint-fn [form line col]
  "Lint fn: check param list brackets, redundant do body."
  (let [issues []]
    (when (>= (len form) 2)
      (let [params (get form 1)]
        (cond
          (isinstance params Expression)
            (.append issues (issue "Use [] for parameter lists, not ()" ERROR line col))
          (and (isinstance params List) (has-do-body? form 1))
            (.append issues (issue "(fn [...] (do ...)) — remove redundant do" INFO line col)))))
    issues))

(defn lint-if [form line col]
  "Lint if: (if cond (do ...)) should be (when cond ...).
  Also checks for redundant do in either branch of a full if/else."
  (let [issues []]
    ;; (if cond (do ...)) with no else → use (when cond ...)
    (when (= (len form) 3)
      (let [consequent (get form 2)]
        (when (and (isinstance consequent Expression)
                   (> (len consequent) 0)
                   (= (get consequent 0) DO))
          (.append issues (issue "(if cond (do ...)) — use (when cond ...)" INFO line col)))))
    ;; (if cond then-expr (do ...)) → redundant do in else (only if single expr)
    (when (= (len form) 4)
      (let [alternative (get form 3)]
        (when (and (isinstance alternative Expression)
                   (= (len alternative) 2)
                   (= (get alternative 0) DO))
          (.append issues (issue "(if cond x (do ...)) — remove redundant do in else branch" INFO line col)))))
    issues))

(defn lint-when [form line col]
  "Lint when/unless: redundant do body."
  (let [issues []]
    (when (has-do-body? form 1)
      (.append issues (issue "(when/unless cond (do ...)) — remove redundant do" INFO line col)))
    issues))

(defn lint-do [form line col]
  "Lint bare single-expression do."
  (let [issues []]
    (when (= (len form) 2)
      (.append issues (issue "(do expr) is redundant — use expr directly" INFO line col)))
    issues))

(defn lint-arithmetic [form line col]
  "Lint trivial arithmetic: identity operations, inc/dec suggestions."
  (let [issues []
        head   (get form 0)
        n      (len form)]
    (when (= n 3)
      (let [a (get form 1)
            b (get form 2)]
        (cond
          ;; (+ x 0) or (+ 0 x)
          (and (= head PLUS) (or (= a ZERO) (= b ZERO)))
            (.append issues (issue "(+ x 0) — adding zero is redundant" INFO line col))
          ;; (* x 1) or (* 1 x)
          (and (= head STAR) (or (= a ONE) (= b ONE)))
            (.append issues (issue "(* x 1) — multiplying by one is redundant" INFO line col))
          ;; (+ x 1) or (+ 1 x) → (inc x)
          (and (= head PLUS) (or (= a ONE) (= b ONE)))
            (.append issues (issue "(+ x 1) — use (inc x) from hyrule" INFO line col))
          ;; (- x 1) → (dec x)
          (and (= head MINUS) (= b ONE))
            (.append issues (issue "(- x 1) — use (dec x) from hyrule" INFO line col)))))
    issues))

(defn lint-import [form line col]
  "Lint old-style import syntax.

  (import [module [sym1 sym2]]) was removed in Hy 1.0 and will fail to
  compile. Use (import module [sym1 sym2]) instead."
  (let [issues []]
    (when (and (>= (len form) 2) (isinstance (get form 1) List))
      (.append issues (issue "Old-style import — use (import module [sym1 sym2])" ERROR line col)))
    issues))

;; * File entry points
(defn lint-file [fname]
  "Lint a single Hy file, return list of issues."
  (import beautifhy.core [slurp])
  (lint-forms (list (read-many (slurp fname)))))

(defn lint-files [fnames]
  "Lint multiple Hy files."
  (let [issues []]
    (for [f fnames]
      (.extend issues (lint-file f)))
    issues))

;; * Reporting
(defn report-issues [issues [filename "<input>"]]
  "Print issues to stderr and return summary dict."
  (let [error-count   0
        warning-count 0]
    (for [i issues]
      (let [sev  (:severity i ERROR)
            line (:line i 0)
            col  (:column i 0)
            msg  (:message i "")]
        (print f"{filename}:{line}:{col}: {sev}: {msg}" :file hy.I.sys.stderr)
        (cond
          (= sev ERROR)   (+= error-count 1)
          (= sev WARNING) (+= warning-count 1))))
    (when issues
      (print f"\n{filename}: {error-count} error(s), {warning-count} warning(s)" :file hy.I.sys.stderr))
    {"errors" error-count "warnings" warning-count "total" (len issues)}))
