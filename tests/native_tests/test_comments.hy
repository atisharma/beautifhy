"Tests for comment preservation during formatting."

(import beautifhy.beautify [grind _repr])
(import beautifhy.reader [HyReaderWithComments Comment])
(import hy.reader [read-many])


(defn has-comment? [result comment-text]
  "Check if comment text appears in result."
  (in comment-text result))


(defn test-cond-preserves-comments []
  "Test that comments are preserved in cond expressions."
  (let [code "(cond
  ;; check for one
  (= x 1)
  'one

  ;; check for two
  (= x 2)
  'two)"
        result (grind code)]
    (assert (has-comment? result ";; check for one"))
    (assert (has-comment? result ";; check for two"))))


(defn test-cond-without-comments []
  "Test that cond without comments still works correctly."
  (let [code "(cond
  (= x 1)
  'one

  (= x 2)
  'two)"
        result (grind code)]
    (assert (in "(= x 1)" result))
    (assert (in "'one" result))))


(defn test-let-preserves-comments []
  "Test that comments are preserved in let bindings."
  (let [code "(let [;; comment for a
      a 1
      ;; comment for b
      b 2]
  (+ a b))"
        result (grind code)]
    (assert (has-comment? result ";; comment for a"))
    (assert (has-comment? result ";; comment for b"))))


(defn test-top-level-comment []
  "Test that top-level comments are preserved."
  (let [code ";; Top level comment
(defn foo []
  \"A function.\")"
        result (grind code)]
    (assert (has-comment? result ";; Top level comment"))))


(defn test-multiple-comments-before-pair []
  "Test that multiple comments before a pair are preserved."
  (let [code "(cond
  ;; First comment
  ;; Second comment
  (= x 1)
  'one)"
        result (grind code)]
    (assert (has-comment? result ";; First comment"))
    (assert (has-comment? result ";; Second comment"))))


(defn test-comment-reader-works []
  "Test that HyReaderWithComments correctly reads comments."
  (let [code ";; test comment\n(defn foo [])"
        forms (list (read-many code :reader (HyReaderWithComments) :skip-shebang True))]
    (assert (= 2 (len forms)))
    (assert (isinstance (get forms 0) Comment))
    (assert (= ";; test comment" (cut (_repr (get forms 0)) 0 -1)))))
