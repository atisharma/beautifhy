"""
Tests for hylight CLI.
"""

(import subprocess sys os pathlib [Path])

;; ── Setup ───────────────────────────────────────────────────────────────────

(setv VENV-BIN (Path (os.path.dirname sys.executable))
      HYLIGHT-CMD (str (VENV-BIN.joinpath "hylight")))


;; ── Tests ────────────────────────────────────────────────────────────────────

(defn test-hylight-help-prints-usage []
  (let [result (subprocess.run [HYLIGHT-CMD "--help"]
                               :capture-output True
                               :text True)]
    (assert (= result.returncode 0))
    (assert (in "usage:" result.stdout))))

(defn test-hylight-version-prints-version []
  (let [result (subprocess.run [HYLIGHT-CMD "--version"]
                               :capture-output True
                               :text True)]
    (assert (= result.returncode 0))
    (assert (in "hylight" result.stdout))))
