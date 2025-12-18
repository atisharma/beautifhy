## 🦑 Beautifhy

*A [Hy](https://hylang.org) beautifier / code formatter / pretty-printer.*

Probably compatible with Hy 1.0.0 and later.


### Install

```bash
$ pip install -U beautifhy
```

The pygments style may be modified with the environment variable
`HY_PYGMENTS_STYLE`. This sets the name of a pygments style to use for
highlighting. Defaults to `lightbulb`.


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

### Acknowledgements

The whole library uses [pygments](https://pygments.org/).
The autoformatter relies on polymorphic dispatch provided by [multimethod](https://coady.github.io/multimethod/).


### Docs

The docstrings are not bad. Otherwise, try clicking below.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/atisharma/beautifhy)
