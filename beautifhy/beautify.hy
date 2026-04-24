"
A Hy source code pretty-printer.

The basic algorithm is as Picolisp does:
> If an expression is atomic or has a size less or equal to 12, then print it.
> Otherwise, print a left parenthesis, recurse on the CAR, then recurse
> on the elements in the CDR, each on a new line indented by 3 spaces.
> Finally print a right parenthesis.

Here we use 2 spaces for indentation (by default).
There are a special cases about when not to break to the next line,
to handle paired `cond`, `let` assignments, etc.

Comments are kept by HyReaderWithComments and rendered by the Comment
handler. They are filtered out before pairing logic so they don't break
cond/let/setv pairing.

NOTE: The final test of any change is to run `beautifhy beautifhy.hy`
and visually inspect the output. Unit tests cover specific cases but
cannot capture every interaction between comments, indentation, and
special forms.
"

(require hyrule [-> ->> unless of defmain])
(require beautifhy.core [defmethod rest])

(import hyrule [inc dec flatten])
(import beautifhy.core [slurp first second last])
(import beautifhy.reader [HyReaderWithComments Comment])
(import itertools [batched]) ;; batched was introduced in python 3.12

(import multimethod [DispatchError])

(import hy.models [Object Complex FComponent FString Float Integer Keyword String Symbol])
(import hy.models [Lazy Expression Sequence Object List Set Dict Tuple])
(import hy.reader [read-many])


(setv SIZE 12)         ; The size of expressions above which they are broken up.
(setv STR_SIZE 75)     ; The size of string at which it's rendered as a multi-line
                       ; (rendering \n as newlines)
(setv INDENT_STR "  ") ; The indentation used to signify levels (two spaces).

(setv Atom (| Complex FComponent FString Float Integer Keyword Symbol Comment))


;; * Tests whether a form is ready to render
;; -----------------------------------------

(defmethod _is-printable [#^ (| Expression Sequence) form * [size SIZE] [str-size STR_SIZE]]
    ;; Forms containing Comments cannot render inline via hy.repr
    ;; (which doesn't handle Comment indentation), so force them
    ;; through grind's layout engine instead.
    (and (not (any (map (fn [f] (isinstance f Comment)) form)))
         (<= (len (flatten form)) size)))

(defmethod _is-printable [#^ String form * [size SIZE] [str-size STR_SIZE]]
    (<= (len form) str-size))

(defmethod _is-printable [#^ Atom form * [size SIZE] [str-size STR_SIZE]]
    True)

(defmethod _is-printable [#^ Object form * [size SIZE] [str-size STR_SIZE]]
    True)


;; * Render forms to text
;; -----------------------------------------

(defn _indent [#^ str indent-str]
  (+ indent-str INDENT_STR))

(defmethod _repr [#^ Object f]
  "The default rendering to string.
  Lose the quote."
  (rest (hy.repr f)))

(defmethod _repr [#^ Keyword f]
  "Keep the : at the front of the keyword."
  (hy.repr f))

(defmethod _repr [#^ List forms]
  "Lose the quote."
  (+ "["
     (.join " "
            (lfor f forms
                  (_repr f)))
     "]"))

(defmethod _repr [#^ Expression forms]
  "Lose the quote, restore type hint and quasiquote."
  (cond

    ;; type hints
    (and (= (len forms) 3)
         (= (first forms) 'annotate))
    f"#^ {(_repr (last forms))} {(_repr (second forms))} "

    ;; quasiquote
    (= (first forms) 'quasiquote)
    (+ "`"
       (.join " "
              (lfor f (rest forms)
                    (_repr f))))

    :else
    (rest (hy.repr forms))))


;; * Special cases
;; -----------------------------------

(defmethod _is-def [#^ Object form]
  "Test if an expression has the first form starting with `'def`."
  False)

(defmethod _is-def [#^ Symbol form]
  "Test if an expression has the first form starting with `'def`."
  (.startswith (_repr form) "def"))
  
(defmethod _is-comprehension [#^ Object form]
  "Test if an expression is a list comprehension."
  False)

(defmethod _is-comprehension [#^ Symbol form]
  "Test if an expression is a list comprehension."
  (in (_repr form) ["lfor" "gfor" "sfor" "dfor"]))

(defmethod _is-paired [#^ Object object #** kwargs]
  "When some symbols are encountered, the next forms go in pairs."
  False)

(defmethod _is-paired [#^ Symbol symbol #** kwargs]
  "When some symbols are encountered (e.g. `cond`), the next forms go in pairs."
  ;; There's no point pairing setv, since the reader expands
  ;; a compound setv statement into individual ones anyway.
  (in symbol ['cond 'setv 'setx]))

(defmethod _takes-paired-list [#^ Object object #** kwargs]
  "When some symbols are encountered, the next form is a paired `List`."
  False)

(defmethod _takes-paired-list [#^ Symbol symbol #** kwargs]
  "When some symbols are encountered, the next form is a paired `List`."
  (in (_repr symbol) ["for" "let" "loop" "with"]))

(defmethod _breaks-line [#^ Object form]
  "The default is to break the expression when it's too long."
  True)

(defmethod _breaks-line [#^ Symbol symbol]
  "When these symbols are encountered, the next form follows on the same line,
  unless it's too long."
  (cond
    ;; It's a heuristic, but a reasonable one.
    (in (cut (_repr symbol) 3) ["def"])
    False

    (in symbol
        ['import 'except
         'if 'when 'unless
         'filter 'map 'accumulate 'reduce 'of
         'setv 'setx 'let
         'for 'get 'match 'case 'branch 'range 'while
         'with '. 'join 'keywords])
    False

    :else
    True))

(defmethod _breaks-line [#^ Keyword form]
  False)

(defmethod _breaks-line [#^ Comment form]
  "Comments starting with ;; start on their own line.
  Single-; trailing comments stay on the same line as the preceding form."
  (.startswith (_repr form) ";;"))

(defmethod _breaks-line [#^ Expression forms]
  "Methods / dotted identifiers have a particular form:
      ([. None Symbol])."
  (not (= (first forms) '.)))


;; * Separator helpers
;; -----------------------------------

(defn _section-comment? [form]
  "Is this a section-separating comment (e.g. ;; * or ;; ---)?"
  (and (isinstance form Comment)
       (let [text (_repr form)]
         (or (.startswith text ";; *")
             (.startswith text ";; -")))))

(defn _trailing-comment? [form]
  "Is this a trailing (end-of-line) comment? Single-; only."
  (and (isinstance form Comment)
       (.startswith (_repr form) ";")
       (not (.startswith (_repr form) ";;"))))

(defn _is-def-form? [form]
  "Is this a defn/defmethod/defclass/defmacro form?"
  (and (isinstance form Expression)
       (> (len form) 0)
       (isinstance (first form) Symbol)
       (_is-def (first form))))

(defn _separator [f next-f indent-str]
  "Determine the separator after form f, before next-f.
  Section comments and def-forms get blank lines.
  Trailing comments stay on the same line as the preceding form."
  (cond
    ;; blank line around section comments
    (or (_section-comment? f)
        (_section-comment? next-f))
    (+ "\n\n" indent-str " ")

    ;; blank line around def-forms (defn, defmethod, defclass, etc.)
    (or (_is-def-form? f)
        (_is-def-form? next-f))
    (+ "\n\n" indent-str " ")

    ;; after trailing comment — new line for next form
    (_trailing-comment? f)
    (+ "\n " indent-str " ")

    ;; before trailing comment — same line as current form
    (_trailing-comment? next-f)
    " "

    ;; normal line-breaking form
    (_breaks-line f)
    (+ "\n " indent-str " ")

    ;; inline form
    :else
    " "))

;; * The layout engine
;; -----------------------------------

;; * Layout helpers
;; -----------------------------------
;; Each helper handles one layout case for sequences of forms.

(defn _layout-short-paired [forms indent-str size]
  "Short paired forms: render each pair inline, preserving comments."
  (let [items (list forms)
        result []
        pending-comments []
        i 0]
    (while (< i (len items))
      (setv item (get items i))
      (if (isinstance item Comment)
          ;; accumulate comments
          (do
            (.append pending-comments (cut (_repr item) 0 -1))
            (+= i 1))
          ;; pair with next non-comment
          (do
            (setv a item)
            (setv j (+ i 1))
            (while (and (< j (len items))
                        (isinstance (get items j) Comment))
              (+= j 1))
            (when (< j (len items))
              ;; render pending comments
              (when pending-comments
                (.append result (.join (+ "\n" (_indent indent-str))
                                       pending-comments))
                (setv pending-comments []))
              (.append result (+ (grind a :indent-str (_indent indent-str) :size size)
                                 " "
                                 (grind (get items j) :indent-str (_indent indent-str) :size size)))
              (setv i (+ j 1))
              (continue))
            ;; no pair found
            (.append result (grind a :indent-str (_indent indent-str) :size size))
            (+= i 1))))
    ;; flush remaining comments
    (when pending-comments
      (.append result (.join (+ "\n" (_indent indent-str))
                             pending-comments)))
    (.join (+ "\n" indent-str) result)))


(defn _layout-aligned-pairs [forms indent-str size]
  "Long paired forms with short LHS: align values to the widest key."
  (let [non-comment-forms (list (filter (fn [f] (not (isinstance f Comment)))
                                        forms))
        instr (* " " (max (map (fn [f] (len (_repr f)))
                              (cut non-comment-forms 0 None 2))))]
    (.join (+ "\n" indent-str)
           (lfor [a b] (batched non-comment-forms 2)
               (+ (grind a :indent-str (_indent indent-str) :size size)
                  (cut instr (len (_repr a)) None) " "
                  (grind b :indent-str (+ instr (_indent indent-str)) :size size))))))


(defn _layout-long-paired [forms indent-str size]
  "Long paired forms: blank line between pairs, preserving comments."
  (let [items (list forms)
        blocks []
        pending-comments []
        i 0]
    (while (< i (len items))
      (setv item (get items i))
      (if (isinstance item Comment)
          ;; accumulate comments to prepend to next pair
          (do
            (.append pending-comments (cut (_repr item) 0 -1))
            (+= i 1))
          ;; pair with next non-comment item
          (do
            (setv a item)
            (setv j (+ i 1))
            ;; skip comments to find the value
            (while (and (< j (len items))
                        (isinstance (get items j) Comment))
              (+= j 1))
            (when (< j (len items))
              (setv pair-str (+ (grind a :indent-str (_indent indent-str) :size size)
                                "\n\n" (_indent indent-str)
                                (grind (get items j) :indent-str (+ "__" (_indent indent-str)) :size size)))
              ;; prepend pending comments
              (when pending-comments
                (setv comment-lines (.join (+ "\n" (_indent indent-str))
                                          pending-comments))
                (setv pair-str (+ comment-lines "\n" (_indent indent-str)
                                  pair-str)))
              (.append blocks pair-str)
              (setv pending-comments [])
              (setv i (+ j 1))
              (continue))
            ;; no pair found (shouldn't happen in valid code)
            (.append blocks (grind a :indent-str (_indent indent-str) :size size))
            (+= i 1))))
    ;; flush any remaining comments
    (when pending-comments
      (.append blocks (.join (+ "\n" (_indent indent-str))
                             pending-comments)))
    (.join (+ "\n" indent-str) blocks)))


(defn _layout-inline [forms indent-str size]
  "Short non-paired forms: render inline."
  (.join " "
         (lfor f forms
               (grind f :indent-str (_indent indent-str) :size size))))


(defn _layout-block [forms indent-str size]
  "Long non-paired forms: one per line."
  (.join (+ "\n" indent-str)
         (lfor f forms
               (grind f :indent-str (_indent indent-str) :size size))))


;; * The layout engine
;; -----------------------------------

(defmethod _layout [#^ Sequence forms * [indent-str ""] [size SIZE] [pair False] #** kwargs]
  "The Hy pretty-printer Sequence layout engine.

  This method applies to a sequence of Hy forms, indenting by `indent-str`.
  It will not wrap in parentheses, brackets or the like. That is done in
  the methods specific to various objects."
  (cond
    ;; short and paired - with comment preservation
    (and pair (_is-printable forms :size size))
    (_layout-short-paired forms indent-str size)

    ;; paired forms with comments always use short-paired layout
    ;; (which preserves comments); aligned-pairs drops them
    (and pair
         (any (map (fn [f] (isinstance f Comment)) forms)))
    (_layout-short-paired forms indent-str size)

    ;; long, paired, and the first of each pair is short enough
    (and pair
         (all (map (fn [form] (_is-printable form :size 3))
                   (cut forms 0 None 2))))
    (_layout-aligned-pairs forms indent-str size)

    ;; long and paired - with comment preservation
    pair
    (_layout-long-paired forms indent-str size)

    ;; short and not paired - just print
    (_is-printable forms :size size)
    (_layout-inline forms indent-str size)

    ;; long and not paired - one on each line
    :else
    (_layout-block forms indent-str size)))


;; * Source code string or Expressions
;; -----------------------------------

(defmethod grind [#^ str source * [size SIZE] #** kwargs]
  "A basic Hy pretty-printer.

  This is a top-level method for a source-code string.
  This is probably what you want to use."
  (let [forms (read-many source
                         :skip-shebang True
                         :reader (HyReaderWithComments :use-current-readers False))]
    (grind forms :size size :source source #** kwargs)))

(defmethod grind [#^ Lazy forms * source #** kwargs]
  "This method is for a lazy sequence of Hy forms."
  (let [form-list (list forms)]
    (.join ""
           (lfor [ix f] (enumerate form-list)
                 (let [next-f (when (< (+ ix 1) (len form-list))
                                (get form-list (+ ix 1)))
                       f-section (_section-comment? f)
                       next-section (_section-comment? next-f)
                       f-def (_is-def-form? f)
                       next-def (_is-def-form? next-f)
                       sep (cond
                             ;; between two section comments: just a line break (grouped)
                             (and f-section next-section) "\n"
                             ;; after a section comment: blank line
                             f-section "\n\n"
                             ;; before a section comment: blank line
                             next-section "\n\n"
                             ;; between two def-forms: blank line
                             (and f-def next-def) "\n\n"
                             ;; after a def-form: blank line
                             f-def "\n\n"
                             ;; before a def-form: blank line
                             next-def "\n\n"
                             ;; trailing comment stays on same line as preceding form
                             (_trailing-comment? f) "\n"
                             (_trailing-comment? next-f) " "
                             ;; default
                             :else "\n")]
                   (+ (grind f #** kwargs) sep))))))

(defmethod grind [#^ Expression forms * [indent-str ""] [size SIZE] #** kwargs] 
  "This method applies to Hy `Expression` objects
  which are parenthesized sequences of Hy forms."
  (cond

    ;; handle very short forms like type hints and (. None f)
    (_is-printable forms :size 3)
    (_repr forms)

    ;; Expressions with the first form starting with `'def` get a
    ;; preceding line and keep the following two forms with them. Skip
    ;; this if the first three forms (usually includes argument
    ;; signature) are too long or the second form is a list (function
    ;; decorator).
    (and
      (_is-def (first forms))
      (_is-printable (cut forms 3))
      (not (isinstance (get forms 1) List))
      (not (<= (len forms) 3)))
    (+
      indent-str "("
      (.join " "
             (lfor f (cut forms 3)
                   (_repr f)))
      "\n" (_indent indent-str)
      (.join ""
             (lfor [ix f] (enumerate (cut forms 3 None))
                   (let [rest-forms (cut forms 3 None)
                         next-f (when (< (+ ix 1) (len rest-forms))
                                  (get rest-forms (+ ix 1)))
                         sep (if (is-not next-f None) (_separator f next-f indent-str) "")]
                     (+ (grind f :indent-str (_indent indent-str) :size size)
                        sep))))
      ")")

    ;; Expressions that are sequence comprehensions keep the following
    ;; two forms with them. Skip this if the first three forms are too
    ;; long.
    (and
      (_is-comprehension (first forms))
      (_is-printable (cut forms 3)))
    (+
      "("
      (.join " "
             (lfor f (cut forms 3)
                   (_repr f)))
      "\n" (_indent indent-str)
      (.join ""
             (lfor [ix f] (enumerate (cut forms 3 None))
                   (let [rest-forms (cut forms 3 None)
                         next-f (when (< (+ ix 1) (len rest-forms))
                                  (get rest-forms (+ ix 1)))
                         sep (if (is-not next-f None) (_separator f next-f indent-str) "")]
                     (+ (grind f :indent-str (_indent indent-str) :size size)
                        sep))))
      ")")

    ;; Forms like `for`, `let` and `with` take a list determining assignments.
    ;; This list should be paired.
    (_takes-paired-list (first forms))
    (let [instr (_indent (* " " (len (first forms))))] 
      (+ "(" (first forms) " "
         ;; List will be paired off
         ;(_indent indent-str)
         (grind (second forms) :indent-str (+ instr indent-str) :size size :pair True)
         "\n" (_indent indent-str)
         ;; rest is processed as normal
         (.join ""
                (lfor [ix f] (enumerate (cut forms 2 None))
                      (let [rest-forms (cut forms 2 None)
                            next-f (when (< (+ ix 1) (len rest-forms))
                                     (get rest-forms (+ ix 1)))
                            sep (if (is-not next-f None) (_separator f next-f indent-str) "")]
                        (+ (grind f :indent-str (_indent indent-str) :size size) sep))))
         ")"))

    ;; Expressions with `cond` as first form should have the following
    ;; forms go in pairs. Comments are preserved but excluded from pairing.
    (_is-paired (first forms))
    (let [items (rest forms)
          blocks []
          pending-comments []
          i 0]
      (while (< i (len items))
        (setv item (get items i))
        (if (isinstance item Comment)
            ;; accumulate comments to prepend to next pair
            (do
              (.append pending-comments (cut (_repr item) 0 -1))
              (+= i 1))
            ;; pair with next non-comment item
            (do
              (setv a item)
              (setv j (+ i 1))
              ;; skip comments to find the value
              (while (and (< j (len items))
                          (isinstance (get items j) Comment))
                (+= j 1))
              (when (< j (len items))
                (setv pair-str (+ (grind a :indent-str (_indent indent-str) :size size)
                                  "\n" (_indent indent-str)
                                  (grind (get items j) :indent-str (_indent indent-str) :size size)))
                ;; prepend pending comments
                (when pending-comments
                  (setv comment-lines (.join (+ "\n" (_indent indent-str))
                                            pending-comments))
                  ;; add leading indent to pair lines since comments take the first line indent
                  (setv pair-str (+ comment-lines "\n" (_indent indent-str)
                                    pair-str)))
                (.append blocks pair-str)
                (setv pending-comments [])
                (setv i (+ j 1))
                (continue))
              ;; no pair found (shouldn't happen in valid code)
              (.append blocks (grind a :indent-str (_indent indent-str) :size size))
              (+= i 1))))
      ;; flush any remaining comments
      (when pending-comments
        (.append blocks (.join (+ "\n" (_indent indent-str))
                               pending-comments)))
      (+ "(" (first forms) "\n"
         (_indent indent-str)
         (.join (+ "\n\n" (_indent indent-str)) blocks)
         "\n" indent-str ")"))

    ;; Expressions with few enough forms just get printed
    (_is-printable forms :size size)
    (_repr forms)

    ;; All other cases follow default indenting rules.
    :else
    (+
      "("
      (.join ""
             (lfor [ix f] (enumerate forms)
                   (let [next-f (when (< (+ ix 1) (len forms))
                                  (get forms (+ ix 1)))
                         sep (if (is-not next-f None) (_separator f next-f indent-str) "")]
                     (+ (grind f :indent-str (_indent indent-str) :size size)
                        sep))))
      ")")))


;; * Atoms, Strings
;; -----------------------------------

(defmethod grind [#^ String s * [indent-str ""] [size SIZE] #** kwargs]
  "This method applies to Hy `String`."
  (cond
    ;; short, print as is on the same line
    (_is-printable s :size size) (_repr s)
    ;; very long, show multiline string
    :else (+ "\"" (.replace (str s) "\"" r"\"") "\"")))

(defmethod grind [#^ Symbol s #** kwargs]
  "This applies to Hy `Symbol`."
  (_repr s))

(defmethod grind [#^ Atom atom #** kwargs]
  "This applies to atomic (non-sequence) Hy forms that are not overridden
  (as `String` is)."
  (_repr atom))

(defmethod grind [#^ Comment comment #** kwargs]
  "This applies to Comments."
  ;; Strip the trailing newline from _repr so the separator model
  ;; handles line breaks and indentation correctly.
  (cut (_repr comment) 0 -1))



;; * Sequences
;; -----------------------------------

(defmethod grind [#^ Dict expr * [indent-str ""] [size SIZE] #** kwargs] 
  "This is the implementation for `Dict`.
  Key-value pairs are grouped."
  (if (_is-printable expr :size size)
      (_repr expr)
      (+ "{"
         (_layout expr :indent-str (+ " " indent-str) :size size :pair True)
         "}")))

(defmethod grind [#^ List expr * [indent-str ""] [size SIZE] [pair False] #** kwargs] 
  "This is the implementation for `List`.
  The `pair` keyword determines whether the list's items presented in pairs."
  (if (and (not pair) (_is-printable expr :size size))
      (_repr expr)
      (+ "["
         (_layout expr :indent-str (+ " " indent-str) :size size :pair pair)
         "]")))

(defmethod grind [#^ Tuple expr * [indent-str ""] [size SIZE] #** kwargs] 
  "This is the implementation for `Tuple`."
  (if (_is-printable expr :size size)
      (_repr expr)
      (+ "#("
         (_layout expr :indent-str (+ "  " indent-str) :size size :pair False)
         ")")))

(defmethod grind [#^ Set expr * [indent-str ""] [size SIZE] #** kwargs] 
  "This is the implementation for `Set`."
  (if (_is-printable expr :size size)
      (_repr expr)
      (+ "#{"
         (_layout expr :indent-str (+ "  " indent-str) :size size :pair False)
         "}")))


;; * The entrypoints
;; -----------------------------------

(defn grind-file [fname]
  "Pretty-print a hy file."
  (-> fname
      (slurp)
      (grind)
      (print)))
