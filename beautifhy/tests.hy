
(defn a [])
(defn b [])
(setv x 1)

(defreader hi
  '(print "Hello."))

#hi #hi #hi

(defreader do-twice
  (setv x (.parse-one-form &reader))
  `(do ~x ~x))

#do-twice (print "This line prints twice.")

