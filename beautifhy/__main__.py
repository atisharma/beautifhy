"""
For testing, this is useful, but you'd normally use the `hyrepl` entrypoint.
"""

from beautifhy.repl import REPL

if __name__ == "__main__":
    console = REPL()
    console.run()
