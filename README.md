## 🦑 Beautifhy

*A Hy beautifier / code formatter / pretty-printer.*

Probably compatible with Hy 1.0.0 and later.


### Install

```bash
$ pip install -U beautifhy
```

If you want syntax highlighting available (which requires pygments), do instead

```bash
$ pip install -U beautifhy[hylight]
```


### Usage

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
