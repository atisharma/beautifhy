"
Test cases for beautifhy.lint
"

(require hyrule [-> ->>])
(import beautifhy.lint [lint ERROR WARNING INFO])
(import beautifhy.core [issue])


(defn has-message? [issues msg-substr]
  "True if any issue contains msg-substr in its message."
  (any (lfor i issues (in msg-substr (:message i "")))))


(defn test-lint-defn-params-brackets []
  "Test that (defn f (x) ...) is flagged (should be [x])."
  (let [code "(defn foo (x y) (+ x y))"
        issues (lint code)]
    (assert (has-message? issues "Use [] for parameter lists"))))


(defn test-lint-defn-correct []
  "Test that correct (defn f [x] ...) passes."
  (let [code "(defn foo [x y] (+ x y))"
        issues (lint code)]
    ;; Should not have the bracket error
    (assert (not (has-message? issues "Use [] for parameter lists")))))


(defn test-lint-if-with-do []
  "Test that (if c (do ...)) suggests using when."
  (let [code "(if condition (do something))"
        issues (lint code)]
    (assert (has-message? issues "use (when"))))


(defn test-lint-defn-with-do []
  "Test that (defn f [...] (do ...)) is flagged."
  (let [code "(defn foo [x] (do (+ x 1)))"
        issues (lint code)]
    (assert (has-message? issues "redundant do"))))


(defn test-lint-fn-with-do []
  "Test that (fn [...] (do ...)) is flagged."
  (let [code "(fn [x] (do (print x)))"
        issues (lint code)]
    (assert (has-message? issues "redundant do"))))


(defn test-lint-when-with-do []
  "Test that (when c (do ...)) is flagged."
  (let [code "(when cond (do (print 1)))"
        issues (lint code)]
    (assert (has-message? issues "redundant do"))))


(defn test-lint-bare-do []
  "Test that (do x) single-expr do is flagged."
  (let [code "(do (print 1))"
        issues (lint code)]
    (assert (has-message? issues "redundant"))))


(defn test-lint-arithmetic-add-zero []
  "Test that (+ x 0) is flagged."
  (let [code "(+ x 0)"
        issues (lint code)]
    (assert (has-message? issues "adding zero"))))


(defn test-lint-arithmetic-mul-one []
  "Test that (* x 1) is flagged."
  (let [code "(* x 1)"
        issues (lint code)]
    (assert (has-message? issues "multiplying by one"))))


(defn test-lint-arithmetic-inc []
  "Test that (+ x 1) suggests inc."
  (let [code "(+ x 1)"
        issues (lint code)]
    (assert (has-message? issues "inc"))))


(defn test-lint-arithmetic-dec []
  "Test that (- x 1) suggests dec."
  (let [code "(- x 1)"
        issues (lint code)]
    (assert (has-message? issues "dec"))))


(defn test-lint-fn-params-brackets []
  "Test that fn with () params is flagged."
  (let [issues (lint "(fn (x) x)")]
    (assert (has-message? issues "Use [] for parameter lists"))))


(defn test-lint-fn-params-correct []
  "Test that fn with [] params is clean."
  (let [issues (lint "(fn [x] x)")]
    (assert (not (has-message? issues "Use [] for parameter lists")))))


(defn test-lint-if-else-do []
  "Test that redundant do in else branch is flagged."
  (let [issues (lint "(if cond x (do y))")]
    (assert (has-message? issues "redundant do in else"))))

(defn test-lint-if-else-do-multi []
  "Test that do with multiple exprs in else branch is NOT flagged."
  (let [issues (lint "(if cond x (do y z))")]
    (assert (not (has-message? issues "redundant do in else")))))


(defn test-lint-decorated-defn []
  "Test that decorated defn with [] params is clean."
  (let [issues (lint "(defn [some-decorator] foo [x] x)")]
    (assert (not (has-message? issues "Use [] for parameter lists")))))


(defn test-lint-async-defn []
  "Test that :async defn with [] params is clean."
  (let [issues (lint "(defn :async foo [x] x)")]
    (assert (not (has-message? issues "Use [] for parameter lists")))))


(defn test-lint-empty-expression []
  "Test that empty expressions don't crash the linter."
  ;; This shouldn't raise — just return no issues or parse error
  (let [issues (lint "()")]
    (assert (isinstance issues list))))


(defn test-lint-old-style-import []
  "Test that old-style (import [module [sym]]) is flagged as error."
  (let [issues (lint "(import [os [path]])")]
    (assert (has-message? issues "Old-style import"))))


(defn test-issue-structure []
  "Test that issues have the correct structure."
  (let [i (issue "test message" ERROR 5 10)]
    (assert (= (:message i) "test message"))
    (assert (= (:severity i) ERROR))
    (assert (= (:line i) 5))
    (assert (= (:column i) 10))))


(defn test-lint-clean-code []
  "Test that clean code produces no issues."
  (let [code "(defn foo [x] (- x 5))"
        issues (lint code)]
    ;; Should have no issues at all
    (assert (= (len issues) 0))))
