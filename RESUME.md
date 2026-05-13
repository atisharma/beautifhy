# Resuming Beautifhy Phase 2

## Environment

Venv already exists at `/pi/venvs/scratch` with beautifhy installed in editable mode.

```bash
cd /pi/nereus/repos/beautifhy
source /pi/venvs/scratch/bin/activate
python3 -m pytest tests/native_tests/ --assert=plain -v
```

## Current State

All 52 tests pass. Phase 1 changes are in `beautifhy/beautify.hy` and `beautifhy/__init__.py` but **not yet committed**. Run `git diff` to see them. The next session should commit Phase 1 before starting Phase 2, or commit everything together — do NOT lose these changes.

## The Fix to Implement

Read SPEC.md for full details. In short: replace `indent-str` strings with `indent-col` integers throughout `grind` and `_layout` methods.

**The key insight:** When a form breaks with its head on the same line as its parent (e.g. `(when (and`), the child's body lines must indent past the **actual column of the child's opening `(`**, not past the parent's base indent.

```hy
;; OLD (broken — Parinfer infers (and) is empty)
(when (and
    (long)
    (another))
  body)

;; NEW (correct — children at col 9, past (and at col 7)
(when (and
        (long)
        (another))
  body)
```

## Files to Touch

Only `beautifhy/beautify.hy` for Phase 2. `__init__.py` is done.

Key functions that pass `indent-str` and must instead track `indent-col`:
- `grind` (all multimethod signatures)
- `_indent` — change to `_indent-col [col]`
- `_layout-*` — all five helpers
- `_grind-with-separator`, `_grind-def-form`, `_grind-comprehension`, `_grind-paired-list`, `_grind-paired`

## Multimethod Gotcha

`grind` is a multimethod dispatching on the type of the first argument. Changing its signature to add `indent-col` means updating **all** `defmethod grind` definitions. They must remain consistent or `DispatchError` will fire at runtime.

The current signatures use `* [indent-str ""] [size SIZE] [pair False] #** kwargs`.
Replace with `* [indent-col None] [size SIZE] [pair False] #** kwargs` and derive `indent-str` as `(* " " (or indent-col 0))` where needed.

## Testing During Phase 2

```bash
# Run full suite after every meaningful change
source /pi/venvs/scratch/bin/activate
python3 -m pytest tests/native_tests/ --assert=plain -v

# Visual check on the canonical example
beautifhy beautifhy/lint.hy > /tmp/out.hy
# Verify (when (and sub-clauses indent past the (and opener column
```

## Commit Before Departure

```bash
git add -A
git commit -m "[beautifhy] Phase 1: setv tidy, type-hint space, closing paren, trailing blank lines"
# OR include Phase 2 if complete
git commit -m "[beautifhy] Parinfer-compatible opener-column indentation"
```
