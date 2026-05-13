# Beautifhy Parinfer-Compatible Indentation

## Status

**Phase 1 complete. Phase 2 complete.**

All changes tracked in `/pi/nereus/repos/beautifhy/beautifhy/beautify.hy`.

## Problem Summary

Beautifhy indents broken child forms relative to the parent's indent string. This breaks Parinfer, which infers paren structure from indentation.

**Parinfer's invariant: children must be indented past the column of the `(` that opened their parent.**

When a form breaks with its head on the same line as its parent (e.g. `(when (and`), the opener `(` of the child is NOT at the start of the parent's indent. The child's children must be indented past that opener column.

### Before (Broken)

```hy
(when (and
    (long-thing x y z)      ; column 4 — LEFT of (and at column 6
    (another x y z))         ; Parinfer infers: (and) is empty
  body)
```

### After (Parinfer-Correct)

```hy
(when (and
        (long-thing x y z)  ; column 8 — past (and at column 6 + INDENT
        (another x y z))
  body)
```

**Rule: when a form breaks, indent its children past the column of its opening `(` + `len(INDENT_STR)`.**

## Phase 1 Fixes (Complete)

All 52 tests pass (`pytest tests/native_tests/ --assert=plain -v`).

| Fix | File | Description |
|-----|------|-------------|
| setv explosion | `beautify.hy` | Removed `setv`/`setx` from `_is-paired` — reader already expands compound setv |
| Type-hint space | `beautify.hy` | Removed trailing space in type-hint `_repr` |
| Closing paren newline | `beautify.hy` | Removed `\n` before `indent-str ")"` in `_grind-paired` — `)` hugs last clause |
| Trailing blank lines | `__init__.py` | Removed extra `print()` calls; `grind` no longer emits trailing `\n` for last form |

## Phase 2: Opener-Column Indentation (Complete)

### The Fix

Replaced `indent-str` string parameter with `indent-col` integer throughout `grind` and `_layout` methods. Indent strings are computed on the fly as `(* " " indent-col)`.

**The key change:** In `_grind-with-separator`, track `prev-sep` (the separator before the current form) and `current-col` (the column position on the current line). When a form is inline (separator before it is a space), pass `current-col` as its `indent-col`, so its children indent past its actual opener column.

### Files Changed

**`beautify.hy`:**
- Add `_indent-col`, `_str-col`, `_last-line-len` helpers
- `_separator` takes `indent-col` instead of `indent-str`
- `_grind-with-separator` rewritten to track `prev-sep` and `current-col`
- `_grind-def-form`, `_grind-comprehension`, `_grind-paired-list`, `_grind-paired` use `indent-col`
- All `grind` multimethods use `indent-col` parameter (default 0)

### Verification

```bash
# Run full suite
cd /pi/nereus/repos/beautifhy
source /pi/venvs/scratch/bin/activate
python3 -m pytest tests/native_tests/ --assert=plain -v

# Visual check
beautifhy beautifhy/lint.hy > /tmp/out.hy
# Verify (when (and sub-clauses indent past the (and opener column
```
