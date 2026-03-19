"""
Tests for beautifhy CLI - Help and version flags.
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


;; ── Tests ────────────────────────────────────────────────────────────────────

(defn test-help-prints-usage []
  (let [result (run-beautifhy ["--help"])]
    (assert (= result.returncode 0))
    (assert (in "usage:" result.stdout))
    (assert (in "--help" result.stdout))
    (assert (in "--version" result.stdout))
    (assert (in "--write" result.stdout))
    (assert (in "--check" result.stdout))))

(defn test-help-short-flag []
  (let [result (run-beautifhy ["-h"])]
    (assert (= result.returncode 0))
    (assert (in "usage:" result.stdout))))

(defn test-version-prints-version []
  (let [result (run-beautifhy ["--version"])]
    (assert (= result.returncode 0))
    (assert (in "beautifhy" result.stdout))))

(defn test-version-short-flag []
  (let [result (run-beautifhy ["-v"])]
    (assert (= result.returncode 0))
    (assert (in "beautifhy" result.stdout))))
