"
Test cases for beautifhy.style
"

(import beautifhy.style [lint-style WARNING INFO])
(import beautifhy.core [issue])


(defn has-message? [issues substr]
  "True if any issue contains substr in its message."
  (any (lfor i issues (in substr (:message i "")))))


(defn test-style-camel-case []
  "Test that camelCase function names are flagged."
  (let [issues (lint-style "(defn myFunc [x] \"doc\" x)")]
    (assert (has-message? issues "kebab-case"))))


(defn test-style-kebab-case-clean []
  "Test that kebab-case names are not flagged."
  (let [issues (lint-style "(defn my-func [x] \"doc\" x)")]
    (assert (not (has-message? issues "kebab-case")))))


(defn test-style-missing-docstring []
  "Test that defn without docstring is flagged."
  (let [issues (lint-style "(defn foo [x] (+ x 1))")]
    (assert (has-message? issues "docstring"))))


(defn test-style-has-docstring-clean []
  "Test that defn with docstring is not flagged for docstring."
  (let [issues (lint-style "(defn foo [x] \"Add one.\" (+ x 1))")]
    (assert (not (has-message? issues "docstring")))))


(defn test-style-trailing-comma []
  "Test that trailing commas in params are flagged."
  (let [issues (lint-style "(defn foo [x,] \"doc\" x)")]
    (assert (has-message? issues "trailing comma"))))


(defn test-style-earmuffs []
  "Test that earmuff variable names are flagged."
  (let [issues (lint-style "(setv *global* 42)")]
    (assert (has-message? issues "Earmuffs"))))


(defn test-style-earmuffs-clean []
  "Test that normal variable names are not flagged."
  (let [issues (lint-style "(setv GLOBAL 42)")]
    (assert (not (has-message? issues "Earmuffs")))))


(defn test-style-clean-code []
  "Test that fully clean code produces no style issues."
  (let [issues (lint-style "(defn good-fn [x] \"Does something.\" (- x 5))")]
    (assert (= (len issues) 0))))


(defn test-issue-structure []
  "Test that style issues have the correct structure."
  (let [i (issue "test" WARNING 3 7)]
    (assert (= (:message i) "test"))
    (assert (= (:severity i) WARNING))
    (assert (= (:line i) 3))
    (assert (= (:column i) 7))))
