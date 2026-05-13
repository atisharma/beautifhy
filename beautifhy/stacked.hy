"
A stack-based Hy pretty-printer prototype.

The core idea: instead of ad-hoc special cases in grind(Expression),
we define a small set of layout strategies and use a context stack
to determine how children are formatted.

Each frame on the stack describes how to lay out the children of a form:
  {:type :block :indent 2}     -- each child on its own line, indented
  {:type :line :indent 0}      -- all children on one line
  {:type :pair :indent 2}      -- children pair up (cond, setv)
  {:type :header :indent 0 :count N}  -- next N children on header line

A form's head symbol determines the layout strategy for its children.
"

(require hyrule [-> ->> unless of defmain])
(require beautifhy.core [defmethod rest])
(import hyrule [inc dec flatten])
(import itertools [batched])

(import beautifhy.core [slurp first second])
(import hy.models [Object Complex FComponent FString Float Integer Keyword String Symbol])
(import hy.models [Lazy Expression Sequence List Set Dict Tuple])
(import hy.reader [read-many])


;; * Configuration
;; -----------------------------------------

(setv SIZE 12)
(setv INDENT "  ")


;; * Context frames
;; -----------------------------------------
;; Each frame describes how children of the current form are laid out.

(defn frame [type #* kwargs]
  "Create a context frame.
  Usage: (frame \"block\" \"indent\" 2)"
  (let [d {"type" type}
        pairs (partition kwargs 2)]
    (for [p pairs]
      (setv k (get p 0)
            v (get p 1))
      (setv (get d k) v))
    d))

(defn partition [seq n]
  "Partition seq into groups of n."
  (let [result []]
    (for [i (range 0 (len seq) n)]
      (.append result (cut seq i (+ i n))))
    result))


;; * Layout dispatch
;; -----------------------------------------
;; Given a form's head symbol, return the layout strategy for its children.

(defn layout-for [head-symbol]
  "Return a list of context frames for the children of a form headed by `head-symbol`."
  (let [sym (_repr head-symbol)]
    (cond

      ;; defn, defclass, fn, lambda: name [args] on header, body indented
      (in sym ["defn" "defclass" "fn" "lambda"])
      [(frame "header" "count" 2)
       (frame "block" "indent" 2)]

      ;; def, defmacro, defreader: name on header, body indented
      (in sym ["def" "defmacro" "defreader"])
      [(frame "header" "count" 1)
       (frame "block" "indent" 2)]

      ;; let, for, loop, with: bindings list on header, body indented
      (in sym ["let" "for" "loop" "with"])
      [(frame "header" "count" 1)
       (frame "block" "indent" 2)]

      ;; cond, setv, setx: pairs
      (in sym ["cond" "setv" "setx"])
      [(frame "pair" "indent" 2)]

      ;; if, when, unless: test on header, branches indented
      (in sym ["if" "when" "unless"])
      [(frame "header" "count" 1)
       (frame "block" "indent" 2)]

      ;; import, except: all on one line if short
      (in sym ["import" "except"])
      [(frame "line" "indent" 0)]

      ;; Comprehensions: first two on header, body indented
      (in sym ["lfor" "gfor" "sfor" "dfor"])
      [(frame "header" "count" 2)
       (frame "block" "indent" 2)]

      ;; Default: standard block layout
      :else
      [(frame "block" "indent" 2)])))


;; * Rendering
;; -----------------------------------------
;; render: returns bare form, no leading indent
;; indent is passed down but never prepended to the output

(defn _is-short [form]
  "Check if a form is short enough to render flat."
  (<= (len (flatten form)) SIZE))

(defn _repr [form]
  "Render a form to string, losing outer quotes."
  (cond
    (isinstance form Keyword)
    (hy.repr form)

    (isinstance form String)
    (hy.repr form)

    (isinstance form Expression)
    (rest (hy.repr form))

    :else
    (rest (hy.repr form))))


(defn render-flat [forms]
  "Render forms on a single line."
  (+ "(" (.join " " (lfor f forms (_repr f))) ")"))


(defn render [form [indent ""]]
  "Render a Hy form to bare string (no leading indent).
  indent is the current indentation level, used for children's indent."
  (cond

    ;; Atoms: just repr
    (not (isinstance form Expression))
    (_repr form)

    ;; Expressions: check for special layout
    (isinstance form Expression)
    (let [frames (layout-for (first form))]
      (if (and (_is-short form)
               (= (len frames) 1)
               (= (get (first frames) "type") "block"))
          ;; Short expressions with default layout: render flat
          (render-flat form)
          ;; Special layout or long expression: use frames
          (render-with-frames form indent frames)))

    :else
    (_repr form)))


(defn render-with-frames [form indent frames]
  "Render a form using the given stack of layout frames."
  (if (not frames)
      ;; No frames: default block layout
      (render-block form indent)
      (let [frame (first frames)]
        (cond
          (= (get frame "type") "line")
          (render-line form indent)

          (= (get frame "type") "block")
          (render-block form indent)

          (= (get frame "type") "header")
          (let [count (.get frame "count" 1)]
            (render-header form indent count))

          (= (get frame "type") "pair")
          (render-pair form indent)

          :else
          (render-block form indent)))))


(defn render-block [form indent]
  "Render forms one per line, indented."
  (let [head (first form)
        children (rest form)
        child-indent (+ indent INDENT)]
    (+ "(" (_repr head)
       (if children
           (+ "\n" child-indent
              (.join (+ "\n" child-indent)
                     (lfor f children (render f child-indent))))
           "")
       ")")))


(defn render-header [form indent count]
  "Render first `count` children on header line, rest as block."
  (let [head (first form)
        children (list (rest form))
        header-children (cut children 0 count)
        body-children (cut children count None)
        child-indent (+ indent INDENT)]
    (+ "(" (_repr head)
       (if header-children
           (+ " " (.join " " (lfor f header-children (render f indent))))
           "")
       (if body-children
           (+ "\n" child-indent
              (.join (+ "\n" child-indent)
                     (lfor f body-children (render f child-indent))))
           "")
       ")")))


(defn render-pair [form indent]
  "Render children as test/result pairs."
  (let [head (first form)
        children (list (rest form))
        child-indent (+ indent INDENT)
        pairs (batched children 2)]
    (+ "(" (_repr head)
       (if children
           (+ "\n" child-indent
              (.join (+ "\n\n" child-indent)
                     (lfor [test result] pairs
                           (+ (render test child-indent)
                              "\n" child-indent
                              (render result child-indent)))))
           "")
       ")")))


(defn render-line [form indent]
  "Render all children on one line."
  (+ "(" (.join " " (lfor f form (_repr f))) ")"))


;; * Top-level API
;; -----------------------------------------

(defn grind [source]
  "Pretty-print a Hy source string."
  (let [forms (read-many source :skip-shebang True)]
    (.join "\n"
           (lfor form forms (render form "")))))
