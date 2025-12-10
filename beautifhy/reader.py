"""
A safe character reader for parsing Hy source,
without compiling reader macros,
and preserving comments.
"""

from hy.core.hy_repr import hy_repr_register
from hy.models import Keyword, Symbol

from hy.reader.exceptions import LexException, PrematureEndOfInput
from hy.reader.hy_reader import sym, mkexpr, as_identifier, HyReader


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


class HyReaderWithComments(HyReader):  
    """A HyReader subclass that tokenizes comments."""  
      
    def __init__(self, **kwargs):
        kwargs['use_current_readers'] = False
        super().__init__(**kwargs)

        # The metaclass creates DEFAULT_TABLE for each class independently.
        # The child's DEFAULT_TABLE only has methods defined in the child.
        # Manually merge parent's table first, then child's.
        self.reader_table = {}
        self.reader_table.update(HyReader.DEFAULT_TABLE)
        self.reader_table.update(self.DEFAULT_TABLE)
        
        # Also need to rebuild reader_macros since parent's __init__ 
        # already moved # macros before we fixed reader_table
        self.reader_macros = {}
        for tag in list(self.reader_table.keys()):
            if tag[0] == '#' and tag[1:]:
                self.reader_macros[tag[1:]] = self.reader_table.pop(tag)

    @reader_for(";")
    def line_comment(self, _):

        def comment_closing(c):
            return c == "\n"

        s = self.read_chars_until(comment_closing, ";", is_fstring=False)
        return Comment(s)
