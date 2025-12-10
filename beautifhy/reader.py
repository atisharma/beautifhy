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


class HySafeReader(HyReader):  
    """A HyReader subclass that disables reader macros."""  
      
    def __init__(self, **kwargs):
        kwargs.pop('use_current_readers', None)
        super().__init__(use_current_readers=False, **kwargs)
        
    # Restore parent's reader_table entries (except # which we override)
        parent_table = HyReader.DEFAULT_TABLE.copy()
        parent_table.update(self.reader_table)  # Keep our overrides
        self.reader_table = parent_table
        
        # Clear reader macros
        self.reader_macros.clear()

    @reader_for("#")
    def tag_dispatch(self, key):  
        """Override handler for reader macros (and tag macros) to return reader macro as symbol instead of executing."""  
        if not self.peekc().strip():  
            raise PrematureEndOfInput.from_reader(  
                "Premature end of input while attempting dispatch", self  
            )  
          
        # Read the identifier after #  
        ident = self.read_ident() or self.getc()  
          
        # Return as symbol instead of executing  
        return Symbol(f"#{ident}", from_parser=True)

    @reader_for(";")
    def line_comment(self, _):

        def comment_closing(c):
            return c == "\n"

        s = self.read_chars_until(comment_closing, ";", is_fstring=False)
        return Comment(s)
