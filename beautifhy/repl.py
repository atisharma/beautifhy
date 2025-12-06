"""
An enhanced REPL for the Hy language.

This module provides a feature-rich interactive console for Hy by
extending ``hy.repl.REPL`` with ``prompt_toolkit`` and ``pygments``.
It offers a significantly improved user experience over the standard
REPL with syntax highlighting for input, output, and context-aware
tracebacks that show the relevant source code.
It also offers context-aware tab completion, integrating the standard
Hy REPL's completer with ``prompt_toolkit``.

The primary public class is :class:`REPL`, which can be instantiated and
used to start a custom interactive session.

.. rubric:: Environment Variables

The REPL's behavior can be configured with the following environment variables:

- ``HY_HISTORY``: Path to a file for storing command history. Defaults to
  ``~/.hy-history``.
- ``HY_REPL_PYGMENTS_STYLE``: The name of a Pygments style to use for
  highlighting. Defaults to ``friendly``.
- ``HY_LIVE_COMPLETION``: If set, enables live/interactive autocompletion
  in a dropdown menu as you type.

.. rubric:: Example

.. code-block:: python

    from beautifhy.repl import REPL

    # Create and start the REPL
    repl = REPL()
    repl.run()

"""

import os
import sys
import traceback
import shutil

from code import InteractiveConsole
from hy import mangle, repr, completer as hy_completer
from hy.repl import REPL as _REPL
from hy.compat import PY3_12

from prompt_toolkit import PromptSession
from prompt_toolkit.lexers import PygmentsLexer
from prompt_toolkit.styles import style_from_pygments_cls
from prompt_toolkit.history import FileHistory
from prompt_toolkit.completion import Completer, Completion

from pygments import highlight
from pygments.formatters import TerminalFormatter
from pygments.lexers import HyLexer, PythonTracebackLexer, get_lexer_by_name
from pygments.styles import get_style_by_name, get_all_styles

from beautifhy.highlight import hylight


# --- Handle the REPL history ---

# Persistent REPL history in a file
history_file = os.environ.get("HY_HISTORY", os.path.expanduser("~/.hy-history"))
history = FileHistory(history_file)


# --- REPL syntax highlighting and completion ---

# Read environment variable for theme
style_name = os.environ.get("HY_REPL_PYGMENTS_STYLE", "friendly")
if style_name not in get_all_styles():
    style_name = "friendly"  # fallback

# Convert Pygments style to prompt_toolkit style
pt_style = style_from_pygments_cls(get_style_by_name(style_name))

class HyPTCompleter(Completer):
    """Bridge prompt_toolkit's completion API with Hy's."""

    def __init__(self, namespace=None):
        self.namespace = namespace or {}
        self.c = hy_completer.Completer(self.namespace)

    def get_completions(self, document, complete_event):
        word = document.get_word_before_cursor()
        state = 0
        while True:
            match = self.c.complete(word, state)
            if match is None:
                break
            yield Completion(match, start_position=-len(word))
            state += 1


# --- Traceback handling and highlighting ---

def set_last_exc(exc_info = None):
    """Setting `sys.last_exc`, or `sys.last_type` on earlier Pythons,
    makes it easier for the user to call the debugger."""
    # this is from the standard Hy REPL
    t, v, tb = exc_info or sys.exc_info()
    if PY3_12:
          sys.last_exc = v
    else:
          sys.last_type, sys.last_value, sys.last_traceback = t, v, tb
    return t, v, tb

def _get_lang_from_filename(filename):
    """Guess the language from the filename extension."""
    match os.path.basename(filename):
        case 'py':
            return 'python'
        case 'hy':
            return 'hylang'
        case 'pytb':
            return 'pytb'
        case 'py3tb':
            return 'py3tb'

def _read_file(filename):
    with open(filename, "r") as f:
        f.read()

def _exception_hook(exc_type, exc_value, tb, *, bg='dark', limit=5, lines_around=2, linenos=True, ignore=[]):
    """Syntax highlighted traceback."""
    _tb = tb
    lang = None
    filename = ''
    while _tb:
        filename = _tb.tb_frame.f_code.co_filename
        ext = os.path.basename(filename)
        lang = _get_lang_from_filename(filename)
        if lang and (not any(map(filename.endswith, ignore))):
            source = _read_file(filename)
            lineno = _tb.tb_lineno
            lines = source.split('\n')[lineno - lines_around:lineno + lines_around:None]
            code_lexer = get_lexer_by_name(lang)
            code_formatter = TerminalFormatter(bg=bg, stripall=True, linenos=linenos)
            code_formatter._lineno = lineno - lines_around
            sys.stderr.write(f'  File {Effect.BOLD}{filename}, line {_hy_let_lineno}\n')
            sys.stderr.write(highlight('\n'.join(lines), code_lexer, code_formatter))
            sys.stderr.write('\n')
            break
        else:
            _tb = _tb.tb_next
    fexc = traceback.format_exception(exc_type, exc_value, tb, limit=limit)
    exc_formatter = TerminalFormatter(bg=bg, stripall=True)
    term = shutil.get_terminal_size()
    return sys.stderr.write(highlight(''.join(fexc), PythonTracebackLexer(), exc_formatter))


# --- The custom REPL ---

class REPL(_REPL):
    """
    A Hy REPL console that uses prompt_toolkit for input, instead of the
    builtin/readline's `input` function.
    """
    def __init__(self, locals=None, filename="<stdin>"):
        super().__init__(locals, filename)
        # Create the prompt session and store it in the instance
        self.session = PromptSession(
            lexer=PygmentsLexer(HyLexer),
            history=history,
            completer=HyPTCompleter(self.locals),
            # Setting the HY_LIVE_COMPLETION env var will enable the ptk dropdown
            complete_while_typing=bool(os.environ.get("HY_LIVE_COMPLETION")),
            style=pt_style
        )

        if self.output_fn is repr:
            self.output_fn = hylight

    def raw_input(self, prompt=""):
        """
        Override the default raw_input to use our prompt_toolkit session.
        """
        try:
            return self.session.prompt(prompt)
        except EOFError:
            # Raise clean exit to base class's interact() loop
            raise SystemExit

    def _error_wrap(self, exc_info_override=False, *args, **kwargs):
        """
        Wrap Hy errors with hyjinx's source resolution and syntax highlighting.
        """
        # When `exc_info_override` is true, use a traceback that
        # doesn't have the REPL frames.
        t, v, tb = set_last_exc(exc_info_override and self.locals.get("_hy_exc_info"))
        if exc_info_override:
            sys.last_type = self.locals.get('_hy_last_type', t)
            sys.last_value = self.locals.get('_hy_last_value', v)
            sys.last_traceback = self.locals.get('_hy_last_traceback', tb)
        _exception_hook(t, v, tb)
        self.locals[mangle("*e")] = v
