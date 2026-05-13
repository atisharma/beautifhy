# Resuming Beautifhy Development

## Status

**Phase 1 and Phase 2 complete.** All 52 tests pass.

Committed on `refactor-grind-helpers` branch.

## Environment

Venv at `/pi/venvs/scratch` with beautifhy installed in editable mode.

```bash
cd /pi/nereus/repos/beautifhy
source /pi/venvs/scratch/bin/activate
python3 -m pytest tests/native_tests/ --assert=plain -v
```

## What Was Done

### Phase 1 (Format Hygiene)

- Fixed setv explosion (removed from `_is-paired`)
- Fixed type-hint trailing space
- Fixed closing paren on own line
- Fixed trailing blank lines

### Phase 2 (Opener-Column Indentation)

Replaced `indent-str` strings with `indent-col` integers throughout:

- Added `_indent-col`, `_str-col`, `_last-line-len` helpers
- Rewrote `_grind-with-separator` to track `prev-sep` and `current-col`
- Updated `_separator`, `_grind-def-form`, `_grind-comprehension`, `_grind-paired-list`, `_grind-paired`
- Updated all `grind` multimethods to use `indent-col` parameter

**Key fix:** When a form is inline (separator before it is a space), pass `current-col` as its `indent-col`, so children indent past the actual opener column.

### Verification

```bash
# Run full suite
source /pi/venvs/scratch/bin/activate
python3 -m pytest tests/native_tests/ --assert=plain -v
# 52 passed

# Self-format test
beautifhy beautifhy/beautify.hy > /tmp/out.hy
hylint --error-only /tmp/out.hy
# (no errors)
```

## Next Steps

1. Merge `refactor-grind-helpers` branch to main
2. Tag release (e.g., v1.2.5)
3. Push to upstream

## Key Files

- `beautifhy/beautify.hy` — Main formatter logic
- `SPEC.md` — Problem description and implementation notes
