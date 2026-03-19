"""
Tests for beautifhy CLI - Basic formatting functionality.
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

(defn create-test-file [tmp-path content [filename None]]
  "Create a test .hy file with given content."
  (setv fname (if filename filename "test.hy"))
  (let [f (Path tmp-path fname)]
    (f.write-text content)
    (str f)))


;; ── Tests ────────────────────────────────────────────────────────────────────

(defn test-format-file-prints-to-stdout [tmp-path]
  (let [content "(defn foo [x] (+ x 1))"
        f (create-test-file tmp-path content)
        result (run-beautifhy [f])]
    (assert (= result.returncode 0))
    (assert (in "defn" result.stdout))))

(defn test-format-stdin-prints-to-stdout []
  (let [result (subprocess.run [BEAUTIFHY-CMD "-"]
                               :input "(defn foo [x] (+ x 1))"
                               :capture-output True
                               :text True)]
    (assert (= result.returncode 0))
    (assert (in "defn" result.stdout))))

(defn test-invalid-extension-raises-error [tmp-path]
  (let [p (Path tmp-path "test.txt")]
    (.write-text p "(foo)")
    (let [result (run-beautifhy [(str p)])]
      (assert (!= result.returncode 0))
      (assert (in "Unrecognised file extension" result.stderr)))))
