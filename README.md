## 🦑 Beautifhy

*A Hy beautifier / code formatter / pretty-printer / enhanced REPL.*

Probably compatible with Hy 1.0.0 and later.


### Install

```bash
$ pip install -U beautifhy
```


### REPL

Beautifhy comes with a REPL that implements multi-line editing, completion, input validation and live syntax highlighting.

```bash
$ hyrepl
```

The behaviour of the repl may be modified with the following environment variables.

- `HY_HISTORY`: Path to a file for storing command history. Defaults to `~/.hy-history`.
- `HY_PYGMENTS_STYLE`: The name of a Pygments style to use for highlighting. Defaults to `bw`.
- `HY_LIVE_COMPLETION`: If set, enables live/interactive autocompletion in a dropdown menu as you type.


### Usage: pretty-printer and syntax highlighter

From the command line, to pretty-print the file `core.hy`:
```bash
$ beautifhy core.hy
```
gives the output

```hylang
(import toolz [first second last])

 ;; * Utility things
 ;; -----------------------------------------

(defmacro defmethod [#* args]
  "Define a multimethod (using multimethod.multimethod).
  For example, the Hy code

  `(defmethod f [#^ int x #^ float y]
    (// x (int y)))`

  is equivalent to the following Python code:

  `@multimethod
  def f(x: int, y: float):
      return await x // int(y)`

  You can also define an asynchronous multimethod:

  `(defmethod :async f [#* args #** kwargs]
    (await some-async-function #* args #** kwargs))`
  "
  (if (= :async (first args))
    (let [f (second args) body (cut args 2 None)]
      `(defn :async [hy.I.multimethod.multimethod] ~f ~@body))
    (let [f (first args) body (cut args 1 None)]
      `(defn [hy.I.multimethod.multimethod] ~f ~@body))))


(defn slurp [fname #** kwargs]
  "Read a file and return as a string.
  kwargs can include mode, encoding and buffering, and will be passed
  to open()."
  (let [f (if (:encoding kwargs None) hy.I.codecs.open open)]
    (with [o (f fname #** kwargs)]
      (o.read))))


(defmacro rest [xs]
  "A slice of all but the first element of a sequence."
  `(cut ~xs 1 None))
```

To apply syntax highlighting (no pretty-printing), do
```bash
$ hylight core.hy
```

You can use stdin and pipe by replacing the filename with `-`:
```bash
$ beautifhy core.hy | hylight -
```
which will pretty-print `core.hy` and then syntax highlight the output.


To convert python code to Hy (using [py2hy](https://github.com/hylang/py2hy)), autoformat, then apply syntax highlighting, do
```bash
$ pip3 install py2hy
$ python3 -m py2hy some_code.py | beautifhy - | hylight -
```

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/atisharma/beautifhy)
