"""
🦑 - beautifhy, a Hy code autoformatter / pretty-printer / code beautifier.
"""

import argparse
import hy
import sys

# set the package version
# the major.minor version simply match the assumed Hy version
# except for 1.2.1 where I forgot...
__version__ = "1.2.1"
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
        "-v", "--version",
        action="version",
        version=f"%(prog)s {__version__}"
    )
    parser.add_argument(
        "-w", "--write",
        action="store_true",
        help="Write formatted output back to files (in-place)"
    )
    parser.add_argument(
        "-c", "--check",
        action="store_true",
        help="Check if files would be reformatted (exit with error if so)"
    )
    args = parser.parse_args()

    if not args.files:
        parser.print_help()
        sys.exit(0)

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

    if args.check and check_failed:
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
        "-v", "--version",
        action="version",
        version=f"%(prog)s {__version__}"
    )
    args = parser.parse_args()

    if not args.files:
        parser.print_help()
        sys.exit(0)

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
