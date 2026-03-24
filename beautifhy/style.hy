"
beautifhy.style - Opinionated style linting for Hy

These rules are conventions, not correctness issues. Enable with --style flag.

Opinionated choices:
- camelCase discouraged: Hy uses kebab-case by convention
- Earmuffs (*var*) discouraged: unidiomatic, gets heavily mangled
- Missing docstrings: defn/defmacro should describe their purpose
- Trailing commas in params: Hy doesn't use commas; this is a Python habit
"

(require beautifhy.core [defmethod])

(import hy.models [Expression List Symbol Object String])
(import hy.reader [read-many])
(import beautifhy.core [issue defn-layout])

;; * Severity levels (re-exported for CLI use)
(setv WARNING "warning")
(setv INFO "info")

;; * Dispatcher
;;
;; Note: Symbol inherits from both str and Object, so we cannot use a str
;; overload in the multimethod — it creates an ambiguous dispatch for Symbols.
;; The source-string entry point is therefore a plain function, not a defmethod.

(defn lint-style [source]
  "Style-check Hy source code string.
  Returns [] on parse errors — correctness errors are lint.hy's job."
  (try
    (lint-style-forms (list (read-many source)))
    (except [e Exception]
      [])))

(defn lint-style-forms [forms]
  "Style-check a list of top-level forms."
  (let [issues []]
    (for [f forms]
      (.extend issues (lint-style-form f)))
    issues))

(defmethod lint-style-form [#^ Expression form]
  "Style-check a single expression."
  (let [issues []
        line   (or form.start-line 1)
        col    (or form.start-column 0)]
    (when (and form (> (len form) 0))
      (let [head (get form 0)]
        (when (isinstance head Symbol)
          (cond
            ;; Skip quasiquote bodies — unquote expressions look like code but are data.
            (= head (Symbol "quasiquote"))
              None
            (in head [(Symbol "defn") (Symbol "defun") (Symbol "fn") (Symbol "defmacro")])
              (.extend issues (style-defn-like form line col))
            (= head (Symbol "setv"))
              (.extend issues (style-setv form line col))))
        ;; Don't recurse into quasiquote — its children are template data, not code.
        (when (!= head (Symbol "quasiquote"))
          (for [sub form]
            (.extend issues (lint-style-form sub))))))
    issues))

(defmethod lint-style-form [#^ Object form]
  "Atoms have no style issues."
  [])

;; * Rules

(defn style-defn-like [form line col]
  "Check defn/fn/defmacro for camelCase name, missing docstring, trailing commas.

  Not flagging ClassNames (PascalCase is correct for classes, defined with
  defclass not defn)."
  (let [issues []
        op-name (str (get form 0))
        #(name-idx params-idx) (defn-layout form)
        body-idx (+ params-idx 1)]
    ;; camelCase function name: has uppercase after a lowercase letter
    (when (and (>= (len form) (+ name-idx 1))
               (isinstance (get form name-idx) Symbol))
      (let [fname (str (get form name-idx))
            chars (list fname)]
        (for [i (range 1 (len chars))]
          (when (and (.islower (get chars (- i 1)))
                     (.isupper (get chars i)))
            (.append issues (issue f"Use kebab-case, not camelCase: {fname}" WARNING line col))
            (break)))))
    ;; Missing docstring (defn/defmacro only, not fn)
    (when (and (>= (len form) (+ body-idx 1))
               (in op-name ["defn" "defun" "defmacro"]))
      (let [fname (str (get form name-idx))
            first-body (get form body-idx)]
        (when (not (isinstance first-body String))
          (.append issues (issue f"{op-name} '{fname}' has no docstring" INFO line col)))))
    ;; Trailing commas in parameter list
    (when (>= (len form) (+ params-idx 1))
      (let [params (get form params-idx)]
        (when (isinstance params List)
          (for [p params]
            (when (and (isinstance p Symbol)
                       (.endswith (str p) ","))
              (.append issues (issue f"Remove trailing comma from parameter: {p}" WARNING line col)))))))
    issues))

(defn style-setv [form line col]
  "Check setv for earmuff variable names.

  Earmuffs (*var*) are unidiomatic in Hy and mangle heavily. Use
  UPPER_SNAKE or kebab-case for module-level names instead."
  (let [issues []]
    (when (>= (len form) 2)
      (let [varname (get form 1)]
        (when (isinstance varname Symbol)
          (let [name (str varname)]
            (when (and (.startswith name "*") (.endswith name "*"))
              (.append issues (issue f"Earmuffs are unidiomatic — use UPPER_SNAKE or kebab-case: {name}" INFO line col)))))))
    issues))

;; * Entry points
(defn lint-file-style [fname]
  "Style-check a single Hy file, return list of issues."
  (import beautifhy.core [slurp])
  (lint-style-forms (list (read-many (slurp fname)))))

(defn lint-files-style [fnames]
  "Style-check multiple Hy files."
  (let [issues []]
    (for [f fnames]
      (.extend issues (lint-file-style f)))
    issues))
