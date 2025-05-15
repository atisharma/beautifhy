"""
🦑 - beautifhy, a Hy code autoformatter / pretty-printer / code beautifier.
"""

import hy
import sys

# set the package version
# the major.minor version simply match the assumed Hy version
__version__ = "1.1.0"
__version_info__ = __version__.split(".")


def __cli_grind_files():
    """Pretty-print hy files from the shell."""
    # The first arg is script name, ignore it.
    # - for stdin
    from beautifhy import beautify
    for fname in sys.argv[1:]:
        if fname.endswith(".hy"):
            beautify.grind_file(fname)
            print()
        elif fname == "-":
            code = sys.stdin.read()
            print(beautify.grind(code))
            print()
        else:
            raise ValueError(f"Unrecognised file extension for {fname}.")

def __cli_hylight_files():
    """Syntax highlight hy or python files from the shell."""
    # The first arg is script name, ignore it.
    # - for stdin
    # FIXME: set to light bg, should change to configurable
    from beautifhy import highlight
    from beautifhy.core import slurp
    for fname in sys.argv[1:]:
        if fname.endswith(".hy"):
            lexer = highlight.get_lexer_by_name("hylang")
            code = slurp(fname)
        elif fname.endswith(".py"):
            lexer = highlight.get_lexer_by_name("python")
            code = slurp(fname)
        elif fname == "-":
            lexer = highlight.get_lexer_by_name("hylang")
            code = sys.stdin.read()
        else:
            raise ValueError(f"Unrecognised file extension for {fname}.")
        formatter = highlight.TerminalFormatter(linenos=False, bg="light", stripall=True)
        print()
        print(highlight.highlight(code, lexer, formatter))
        print()
