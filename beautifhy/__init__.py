"""
🦑 - beautifhy, a Hy code autoformatter / pretty-printer / code beautifier.
"""

import hy
import sys

# set the package version
# the major.minor version simply match the assumed Hy version
__version__ = "1.2.1"
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
    from beautifhy import highlight
    from beautifhy.core import slurp
    from pygments.formatters import TerminalFormatter
    from pygments.lexers import get_lexer_by_name
    for fname in sys.argv[1:]:
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
