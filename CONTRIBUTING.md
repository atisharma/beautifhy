# Contributing to beautifhy

This document covers the process for both human and AI-assisted contributions.

## Getting Started

1. Fork the repository (if external) or create a feature branch.
2. Install in development mode: `pip install -e .`
3. Run tests to ensure baseline: `python3 -m pytest tests/ --assert=plain`

## Making Changes

### Codebase

- Follow codebase idioms
- Add tests for new features in `tests/native_tests/`.
- Run the full suite: `python3 -m pytest tests/ --assert=plain`
- All tests must pass before submission.

### Documentation

- Update README.md if adding CLI flags or changing behaviour.
- Docstrings are required for public functions.

## AI-Assisted Contributions

We accept contributions generated with LLM assistance, subject to these requirements:

- **Human review required.** All AI-generated PRs must be reviewed and approved by a human maintainer.
- **Declare non-trivial assistance.** Note in the PR description: "Generated with assistance from [Claude/ChatGPT/etc]."
- **No autonomous merges.** AI agents must not merge, approve, or create releases.
- **Quality bar is the same.** AI-generated code must be idiomatic, pass all tests, and pass lint checks.

See `AGENTS.md` for the concise agent checklist.

## Submission

1. Push your branch to your fork.
2. Open a PR against `main` with a clear description.
3. Respond to review feedback promptly.

## Questions?

Open an issue for discussion before major changes.
