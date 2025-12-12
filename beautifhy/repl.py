"""
An enhanced REPL for Hy.

This module provides a feature-rich interactive console for Hy by
extending ``hy.repl.REPL`` with ``prompt_toolkit`` and ``pygments``.
It offers a significantly improved user experience over the standard
REPL with syntax highlighting for input, output, and context-aware
tracebacks that show the relevant source code.

It also offers context-aware tab completion, integrating the native
Hy REPL's completer with ``prompt_toolkit``.

The primary public class is :class:`HyREPL`, which can be instantiated and
used to start a custom interactive session.

.. rubric:: Environment Variables

The REPL's behavior can be configured with the following environment variables:

- ``HY_HISTORY``: Path to a file for storing command history. Defaults to
  ``~/.hy-history``.
- ``HY_PYGMENTS_STYLE``: The name of a pygments style to use for
  highlighting. Defaults to ``friendly``.
- ``HY_LIVE_COMPLETION``: If set, enables live/interactive autocompletion
  in a dropdown menu as you type.
- ``HY_VI_MODE``: If set, enables vi mode in the REPL (default is emacs).

.. rubric:: Example

.. code-block:: bash

    $ hyrepl

.. code-block:: python

    from beautifhy.repl import HyREPL

    # Create and start the REPL
    repl = HyREPL()
    repl.run()

"""

import io, os, re, sys
import shutil
import traceback

from hy import mangle, repr, completer as hy_completer
from hy.repl import REPL as _REPL

from prompt_toolkit import PromptSession
from prompt_toolkit.application.current import get_app
from prompt_toolkit.completion import Completer, Completion
from prompt_toolkit.formatted_text import FormattedText, ANSI, HTML
from prompt_toolkit.history import FileHistory
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.lexers import PygmentsLexer
from prompt_toolkit.styles import style_from_pygments_cls
from prompt_toolkit.validation import Validator, ValidationError

from pygments import highlight, lex
from pygments.formatters import TerminalFormatter
from pygments.lexers import HyLexer, PythonTracebackLexer, get_lexer_by_name
from pygments.styles import get_style_by_name, get_all_styles
from pygments.token import Token


from beautifhy.highlight import hylight


# --- REPL history, persisted in a file --- #

history_file = os.environ.get("HY_HISTORY", os.path.expanduser("~/.hy-history"))
history = FileHistory(history_file)


# --- REPL syntax highlighting and completion --- #

# Read environment variable for theme
style_name = os.environ.get("HY_PYGMENTS_STYLE", "lightbulb")
bg = "dark" # default, usually fine
if ':' in style_name:
    style_name, bg = style_name.split(':', 1)
if style_name not in get_all_styles():
    style_name = "lightbulb"  # fallback

# Convert pygments style to prompt_toolkit style
pt_style = style_from_pygments_cls(get_style_by_name(style_name))

class HyCompleter(Completer):
    """Wrap prompt_toolkit's completion API around Hy's."""

    def __init__(self, namespace=None):
        self.namespace = namespace or {}
        self.c = hy_completer.Completer(self.namespace)
        # Hy symbols may not use these chars (or ., but we keep that for attrs)
        self._pattern = re.compile(r"[^()\[\]{}\"';`,~\\#\s]+")

    def get_completions(self, document, complete_event):
        # Update namespace reference as it may have changed
        self.c.namespace = self.namespace
        fragment = document.get_word_before_cursor(pattern=self._pattern)
        state = 0
        while True:
            match = self.c.complete(fragment, state)
            if match is None:
                break
            yield Completion(match, start_position=-len(fragment))
            state += 1


# --- REPL traceback handling and highlighting --- #

def _set_last_exc(exc_info = None):
    """Setting `sys.last_exc`, or `sys.last_type` on earlier Pythons,
    makes it easier for the user to call the debugger."""
    # this is from the standard Hy REPL
    t, v, tb = exc_info or sys.exc_info()
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

def _output_traceback(exc_type, exc_value, tb, *, bg=bg, limit=5, lines_around=2, linenos=True, ignore=[]):
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


# --- Multiline input --- #

def _indent_depths(text: str) -> str:
    """
    Calculate indentation for the next line, counting parens using HyLexer.
    """
    tokens = list(lex(text, HyLexer()))
    depths = [0, 0, 0]   # parens, brackets, braces
    for ttype, val in tokens:
        # Ignore strings/comments
        if ttype in Token.Literal.String or ttype in Token.Comment:
            continue
        # Increase/decrease depth for parens/brackets/braces
        depths[0] += val.count("(")
        depths[0] -= val.count(")")
        depths[1] += val.count("[")
        depths[1] -= val.count("]")
        depths[2] += val.count("{")
        depths[2] -= val.count("}")
    return depths

# Key bindings: Enter accepts if complete, otherwise inserts newline.
kb = KeyBindings()

@kb.add("enter")
def _(event):
    """Enter accepts if ([{}])s balance,
    otherwise inserts newline."""
    buf = event.app.current_buffer
    text = buf.document.text

    if any(_indent_depths(text)):
        # Insert newline + smart indentation
        indent = max(0, sum(_indent_depths(text))) * "  "
        buf.insert_text("\n" + indent)
    else:
        buf.validate_and_handle()


# --- The custom REPL --- #

class HyREPL(_REPL):
    """
    A subclass of :class:`hy.repl.REPL`, which is itself a subclass of
    :class:`code.InteractiveConsole`, for Hy.

    This Hy REPL console that uses prompt_toolkit for input, instead of
    hy.REPL's builtin/readline `input` function.

    The REPL's behavior can be configured with the following environment variables:

    - ``HY_HISTORY``: Path to a file for storing command history. Defaults to
      ``~/.hy-history``.
    - ``HY_PYGMENTS_STYLE``: The name of a pygments style to use for
      highlighting. Defaults to ``friendly``.
    - ``HY_LIVE_COMPLETION``: If set, enables live/interactive autocompletion
      in a dropdown menu as you type.
    """

    def __init__(self, locals=None, filename="<stdin>", status=None):

        super().__init__(locals, filename)

        # default ps2 should be of same length as ps1
        self.ps2 = self.ps2[:len(self.ps1)]

        # Create the prompt session and store it in the instance
        self.session = PromptSession(
            lexer=PygmentsLexer(HyLexer),
            history=history,
            completer=HyCompleter(self.locals),
            complete_while_typing=bool(os.environ.get("HY_LIVE_COMPLETION")),
            vi_mode=bool(os.environ.get("HY_VI_MODE", False)),
            bottom_toolbar=status,
            rprompt=self._validation_text,
            key_bindings=kb,
            message=ANSI(self.ps1),
            prompt_continuation=ANSI(self.ps2),
            multiline=True,
            style=pt_style
        )

        # override repr, otherwise keep super's choice, set by HYSTARTUP
        if self.output_fn is repr:
            self.output_fn = hylight

    def raw_input(self, prompt=""):
        """
        Override the default raw_input to use our prompt_toolkit session.
        """
        try:
            return self.session.prompt()
        except EOFError:
            # Raise clean exit to base class's interact() loop
            raise SystemExit

    def _error_wrap(self, exc_info_override=False, *args, **kwargs):
        """
        Wrap Hy errors with hyjinx's source resolution and syntax highlighting.
        """
        # When `exc_info_override` is true, use a traceback that
        # doesn't have the REPL frames.
        t, v, tb = _set_last_exc(exc_info_override and self.locals.get("_hy_exc_info"))
        if exc_info_override:
            sys.last_type = self.locals.get('_hy_last_type', t)
            sys.last_value = self.locals.get('_hy_last_value', v)
            sys.last_traceback = self.locals.get('_hy_last_traceback', tb)
        _output_traceback(t, v, tb)
        self.locals[mangle("*e")] = v

    def _validation_text(self):
        """Return a red 'x' if parentheses don't balance."""
        if any(_indent_depths(self.session.app.current_buffer.text)):
            return FormattedText([('class:red', 'x')])
        else:
            return FormattedText()

