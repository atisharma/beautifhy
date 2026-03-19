"""
Tests for beautifhy CLI - Write (in-place) flag.
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

(defn test-write-formats-file-in-place [tmp-path]
  (let [content "(defn foo[x](+ x 1))"
        f (create-test-file tmp-path content)
        result (run-beautifhy ["--write" f])]
    (assert (= result.returncode 0))
    (assert (in "reformatted" result.stdout))
    (let [new-content (.read-text (Path f))]
      (assert (!= new-content content)))))

(defn test-write-short-flag [tmp-path]
  (let [content "(defn foo[x](+ x 1))"
        f (create-test-file tmp-path content)
        result (run-beautifhy ["-w" f])]
    (assert (= result.returncode 0))
    (assert (in "reformatted" result.stdout))))

(defn test-write-unchanged-file-reports-unchanged [tmp-path]
  (let [content "(defn foo [x] (+ x 1))"
        f (create-test-file tmp-path content)]
    ;; First pass - may or may not reformat
    (subprocess.run [BEAUTIFHY-CMD "--write" f] :capture-output True)
    ;; Second pass on already-formatted file - must report unchanged
    (let [result (run-beautifhy ["--write" f])]
      (assert (= result.returncode 0))
      (assert (in "unchanged" result.stdout)))))
