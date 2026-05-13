# Beautifhy Parinfer-Compatible Indentation

## Status

Phase 1 complete (format hygiene fixes). Phase 2 in progress (indentation fix).

All changes tracked in `/pi/nereus/repos/beautifhy/beautifhy/beautify.hy` and `/pi/nereus/repos/beautifhy/beautifhy/__init__.py`.

## Problem Summary

Beautifhy indents broken child forms relative to the parent's indent string. This breaks Parinfer, which infers paren structure from indentation.

**Parinfer's invariant: children must be indented past the column of the `(` that opened their parent.**

When a form breaks with its head on the same line as its parent (e.g. `(when (and`), the opener `(` of the child is NOT at the start of the parent's indent. The child's children must be indented past that opener column.

### Current (Broken)

```hy
(when (and
    (long-thing x y z)      ; column 4 — LEFT of (and at column 7
    (another x y z))         ; Parinfer infers: (and) is empty
  body)
```

Parinfer rewrites this as:
```hy
(when (and)
    (long-thing x y z)
    (another x y z))
  body)
```

### Expected (Parinfer-Correct)

```hy
(when (and
        (long-thing x y z)  ; column 9 — past (and at column 7
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

## Phase 2: Opener-Column Indentation (TODO)

### The Root Cause

Currently `grind` and `_layout` pass `indent-str` (a string of spaces). Children are indented at `(_indent indent-str)` = `indent-str + INDENT_STR`, which is 2 spaces past the parent line's start. But the child's opening `(` may be much further along the line.

In the `(when (and` example:
- Parent ground at `indent-str=""`
- `(and` child ground at `indent-str="  "` (_indent)
- The `(` of `(and` is at column 6 on the line, not column 2
- But `(and`'s children are indented at column 4 ("    "), not column 8

### Proposed Fix: Convert `indent-str` -> `indent-col`

Replace the `indent-str` string parameter with `indent-col` (an integer) throughout `grind` and `_layout` methods. Indent strings are computed on the fly as `(* " " indent-col)`.

**The key change:** In `_grind-with-separator` (and similar functions that may place a child on the same line as preceding inline elements), compute the child's **virtual indent-col** from the actual column of its opening `(`, not from the parent indent.

```hy
;; OLD: each child gets a fixed indent from parent
(grind child :indent-str (_indent indent-str))

;; NEW: compute inline-opener-col for children placed on the same line
(let [child-col (if inline?
                  (+ current-line-column 1)  ; past the (
                  (+ indent-col INDENT))]     ; new line, normal indent
  (grind child :indent-col child-col))
```

### Files and Functions to Change

**`beautify.hy`:**
- Add `#^ int [indent-col None]` to all `grind` multimethods, defaulting to infer from `indent-str`.
- `_indent` should become `_indent-col [col]` returning `col + len(INDENT_STR)`.
- `_layout-*` helpers pass `indent-col` and compute strings as `(* " " indent-col)`.
- `_grind-with-separator`: track `current-col` and compute `opener-col` for inline children.
- `_grind-def-form`, `_grind-comprehension`, `_grind-paired-list`, `_grind-paired`: compute child `indent-col` from the actual line column of the form's `(`.
- `_layout-block`, `_layout-inline`, `_layout-short-paired`, `_layout-aligned-pairs`, `_layout-long-paired`: use `indent-col`.

**`__init__.py`:**
- No changes needed (Phase 1 complete).

### Algorithm Sketch for `_grind-with-separator`

In `_grind-with-separator [forms indent-col size #** kwargs]`:

1. Initialise `current-col = indent-col` (column of the `(`).
2. Track `line-started? = True` (we always start with `(` on the line).
3. Iterate forms with separator:
   a. For each child, determine if separator is inline (`" "`) or newline.
   b. If newline: child starts fresh. `child-col = (+ indent-col INDENT)`.
   c. If inline: compute `prefix-col` = sum of column widths of all preceding inline forms + spaces. `child-col = (+ prefix-col 1)` (past `(`).
   d. Call `(grind child :indent-col child-col :size size #** kwargs)`.
   e. If child's output contains newlines AND the child was inline, its body lines need to recompute indent relative to `child-col + INDENT`.
   f. After child, update `current-col`.
4. Join all parts with separators.

**Simpler variant:** Since `grind` returns strings, and we don't want to re-indent strings after the fact, pass the `indent-col` down and let `grind` for Expression compute its own children's indent from it. The issue is only that `indent-col` must be set to the opener column of the child form, not the parent's indent.

For a child on a fresh line, opener-col = `indent-col + 1` (the `(` is at `indent-col` spaces). Wait, no — `(+ " " (* " " indent-col))` gives the indent string. The `(` is appended at the start. So the `(` is at column `indent-col`.

For a child inline after preceding forms, opener-col = `column-after-preceding-forms + 1`.

### Alternative: Option B (Avoid Inline Breaking)

Instead of computing opener columns, change `_breaks-line` for `Expression` forms: **always** break the child to a new line if its parent also breaks. This makes the `(` always start at the beginning of the line, so `indent-col` is always correct.

```hy
(when
  (and
    (long)
    (another))
  body)
```

This is architecturally simpler but changes output style. Ati prefers Option A (inline breaking with corrected opener columns).

## Next Session Tasks

1. Decide between Option A (track opener columns) or Option B (force newline).
2. Implement chosen approach in `beautify.hy`.
3. Update or add tests covering the parinfer-incompatible cases.
4. Run full test suite: `pytest tests/native_tests/ --assert=plain -v`
5. Verify `beautifhy beautifhy/lint.hy` output is parinfer-safe.
6. Run `hylint --error-only` on changed Hy files.
7. Commit with `[nereus]` prefix per git workflow.
