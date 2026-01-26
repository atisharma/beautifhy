"""
A safe character reader for parsing Hy source,
without compiling user-defined reader macros,
and preserving comments.
"""

from hy.core.hy_repr import hy_repr_register
from hy.models import Keyword, Symbol

from hy.reader.exceptions import LexException, PrematureEndOfInput
from hy.reader.hy_reader import sym, mkexpr, as_identifier
from hy.hy_inspect import HySafeReader


class Comment(Keyword):
    """Represents a comment up to newline."""

    def __init__(self, value):
        self.name = str(value)

    def __repr__(self):
        return f"hyjinx.reader.{self.__class__.__name__}({self.name!r})"

    def __str__(self):
        "Comments are terminated by a newline."
        return ";%s\n" % self.name

    def __hash__(self):
        return hash(self.name)

    def __eq__(self, other):
        return False

    def __ne__(self, other):
        return True

    def __bool__(self, other):
        return False

    _sentinel = object()

# so the Hy and the REPL knows how to handle it
hy_repr_register(Comment, str)


class HyReaderWithComments(HySafeReader):
    """A HyReader subclass that tokenizes comments."""

    @reader_for(";")
    def line_comment(self, _):

        def comment_closing(c):
            return c == "\n"

        s = self.read_chars_until(comment_closing, ";", is_fstring=False)
        return Comment(s)
