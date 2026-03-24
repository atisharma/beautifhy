# Agent Contribution Guidelines

This file is for AI agents and LLM-assisted workflows contributing to beautifhy.

## Before Submitting

- **All changes require human review.** Do not merge your own PRs.
- **Run tests.** `python3 -m pytest tests/ --assert=plain` must pass.
- **Run linter.** `hylint --style` on changed files.
- **No placeholders.** No TODO/FIXME in submitted code.

## What to Include

- **PR description:** Note AI assistance ("Generated with Claude" or similar).
- **Commit attribution:** `Co-authored-by: Agent <agent@agent-framework.local>` if you did the bulk of the work.

## Do Not

- Merge, approve, or tag releases.
- Modify CI/CD, licensing, or dependencies without explicit human direction.
- Submit bulk changes (>500 lines) without prior discussion.

## Quality Checklist

- [ ] Tests pass
- [ ] `hylint --style` clean (no errors/warnings)
- [ ] Follows existing code patterns
- [ ] Complex logic has comments explaining *why*
- [ ] No hallucinated APIs or dependencies
