"""
🦑 - beautifhy, a Hy code autoformatter / pretty-printer / code beautifier.
"""

import argparse
import hy
import sys

# set the package version
# the major.minor version simply match the assumed Hy version
# except for 1.2.1,2,3 where I forgot...
__version__ = "1.2.5"
__version_info__ = __version__.split(".")


def __cli_grind_files():
    """Pretty-print hy files from the shell."""
    from beautifhy import beautify
    from beautifhy.core import slurp

    parser = argparse.ArgumentParser(
        description="Pretty-print Hy files.",
        prog="beautifhy"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Hy files to format (use '-' for stdin)"
    )
    parser.add_argument(
        "--write", "-w",
        action="store_true",
        help="write formatted output back to files (in-place)"
    )
    parser.add_argument(
        "--check", "-c",
        action="store_true",
        help="check if files need reformatting (CI mode)"
    )
    parser.add_argument(
        "--version", "-v",
        action="version",
        version=f"%(prog)s {__version__}"
    )

    args = parser.parse_args()

    # If no files specified, read from stdin
    if not args.files:
        code = sys.stdin.read()
        print(beautify.grind(code))
        print()
        return

    check_failed = False

    for fname in args.files:
        if fname.endswith(".hy"):
            original = slurp(fname)
            formatted = beautify.grind(original)

            if args.check:
                if original != formatted:
                    print(f"would reformat {fname}", file=sys.stderr)
                    check_failed = True
            elif args.write:
                if original != formatted:
                    with open(fname, "w") as f:
                        f.write(formatted)
                    print(f"reformatted {fname}")
                else:
                    print(f"unchanged {fname}")
            else:
                print(formatted)
                print()

        elif fname == "-":
            code = sys.stdin.read()
            print(beautify.grind(code))
            print()
        else:
            raise ValueError(f"Unrecognised file extension for {fname}.")

    if check_failed:
        sys.exit(1)


def __cli_hylight_files():
    """Syntax highlight hy or python files from the shell."""
    from beautifhy import highlight
    from beautifhy.core import slurp
    from pygments.formatters import TerminalFormatter
    from pygments.lexers import get_lexer_by_name

    parser = argparse.ArgumentParser(
        description="Syntax highlight Hy or Python files.",
        prog="hylight"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Files to highlight (use '-' for stdin)"
    )
    parser.add_argument(
        "--version", "-v",
        action="version",
        version=f"%(prog)s {__version__}"
    )

    args = parser.parse_args()

    # If no files specified, read from stdin
    if not args.files:
        code = sys.stdin.read()
        language = "hylang"
        formatter = TerminalFormatter(style=highlight.style_name, bg=highlight.bg, stripall=True)
        lexer = get_lexer_by_name(language)
        print()
        print(highlight.highlight(code, lexer, formatter))
        print()
        return

    for fname in args.files:
        if fname.endswith(".hy"):
            language = "hylang"
            code = slurp(fname)
        elif fname.endswith(".py"):
            language = "python"
            code = slurp(fname)
        elif fname == "-":
            language = "hylang"
            code = sys.stdin.read()
        else:
            raise ValueError(f"Unrecognised file extension for {fname}.")

        formatter = TerminalFormatter(style=highlight.style_name, bg=highlight.bg, stripall=True)
        lexer = get_lexer_by_name(language)

        print()
        print(highlight.highlight(code, lexer, formatter))
        print()


def __cli_lint_files():
    """Lint Hy files from the shell."""
    import hy
    from beautifhy.lint import lint, report_issues
    from beautifhy.style import lint_style, lint_style_forms
    from beautifhy.core import slurp

    parser = argparse.ArgumentParser(
        description="Lint Hy files for syntax errors and common issues.",
        prog="hylint"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Hy files to lint (use '-' for stdin)"
    )
    parser.add_argument(
        "--style", "-s",
        action="store_true",
        help="also run opinionated style checks (camelCase, docstrings, earmuffs)"
    )
    parser.add_argument(
        "--error-only", "-e",
        action="store_true",
        help="only show errors (not warnings or info)"
    )
    parser.add_argument(
        "--version", "-v",
        action="version",
        version=f"%(prog)s {__version__}"
    )

    args = parser.parse_args()

    def check(code, filename):
        issues = lint(code)
        if args.style:
            issues += lint_style(code)
        if args.error_only:
            issues = [i for i in issues if i.get("severity") == "error"]
        # Sort by line number for readable output
        issues.sort(key=lambda i: (i.get("line", 0), i.get("column", 0)))
        return report_issues(issues, filename=filename)

    total_errors = 0
    total_warnings = 0

    if not args.files:
        result = check(sys.stdin.read(), "<stdin>")
        total_errors += result["errors"]
        total_warnings += result["warnings"]
    else:
        for fname in args.files:
            if fname == "-":
                result = check(sys.stdin.read(), "<stdin>")
            elif fname.endswith(".hy"):
                result = check(slurp(fname), fname)
            else:
                print(f"hylint: unrecognised file extension: {fname}", file=sys.stderr)
                sys.exit(2)
            total_errors += result["errors"]
            total_warnings += result["warnings"]

    if total_errors > 0:
        sys.exit(1)
