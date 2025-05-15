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

    (let [f (second args)
          body (cut args 2 None)]
      `(defn :async [hy.I.multimethod.multimethod] ~f
         ~@body))

    (let [f (first args)
          body (cut args 1 None)]
      `(defn [hy.I.multimethod.multimethod] ~f
         ~@body))))

(defn slurp [fname #** kwargs]
  "Read a file and return as a string.
  kwargs can include mode, encoding and buffering, and will be passed
  to open()."
  (let [f (if (:encoding kwargs None)
              hy.I.codecs.open
              open)]
    (with [o (f fname #** kwargs)]
      (o.read))))

(defmacro rest [xs]
  "A slice of all but the first element of a sequence."
  `(cut ~xs 1 None))
