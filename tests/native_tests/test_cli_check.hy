"""
Tests for beautifhy CLI - Check (CI) flag.
"""

(import subprocess sys os pathlib [Path])

;; ── Setup ───────────────────────────────────────────────────────────────────

(setv VENV-BIN (Path (os.path.dirname sys.executable))
      BEAUTIFHY-CMD (str (VENV-BIN.joinpath "beautifhy")))

(defn run-beautifhy [args]
  "Run beautifhy with given args and return result."
  (subprocess.run [#* [BEAUTIFHY-CMD] #* args]
                  :capture-output True
                  :text True))

(defn create-test-file [tmp-path content [filename "test.hy"]]
  "Create a test .hy file with given content."
  (let [f (Path tmp-path filename)]
    (.write-text f content)
    (str f)))


;; ── Tests ────────────────────────────────────────────────────────────────────

(defn test-check-passes-on-formatted-file [tmp-path]
  (let [content "(defn foo [x] (+ x 1))"
        f (create-test-file tmp-path content)]
    ;; Ensure it is in canonical form first
    (subprocess.run [BEAUTIFHY-CMD "--write" f] :capture-output True)
    (let [result (run-beautifhy ["--check" f])]
      (assert (= result.returncode 0)))))

(defn test-check-fails-on-unformatted-file [tmp-path]
  (let [content "(defn foo[x](+ x 1))"
        f (create-test-file tmp-path content)
        result (run-beautifhy ["--check" f])]
    (assert (!= result.returncode 0))
    (assert (in "would reformat" result.stderr))))

(defn test-check-short-flag [tmp-path]
  (let [content "(defn foo[x](+ x 1))"
        f (create-test-file tmp-path content)
        result (run-beautifhy ["-c" f])]
    (assert (!= result.returncode 0))))

(defn test-check-multiple-files-reports-all [tmp-path]
  (let [f1 (create-test-file tmp-path "(defn a[x]x)" "file1.hy")
        f2 (create-test-file tmp-path "(defn b[y]y)" "file2.hy")
        result (run-beautifhy ["--check" f1 f2])]
    (assert (!= result.returncode 0))
    (assert (in "would reformat" result.stderr))))
