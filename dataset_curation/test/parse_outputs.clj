(ns parse-outputs
  (:require [babashka.http-client :as http]
            [accent.state :refer [setup u]]
            [cheshire.core :as json]
            [clojure.java.io :as io])
  (:import [com.fasterxml.jackson.core JsonParser$Feature]
           [com.fasterxml.jackson.databind ObjectMapper]))

(defn read-jsonl
  "Reads a JSONL file, skipping invalid lines and returning valid JSON objects"
  [file-path]
  (with-open [rdr (io/reader file-path)]
    (doall
     (map #(json/parse-string % true)
            (line-seq rdr)))))

(def input-b (json/parse-string (slurp "input/batch/B.json")))

(def input-c (json/parse-string (slurp "input/batch/C.json")))

(def output-b
  (read-jsonl "output/batch/batch_67df5faa13f08190b9a130d96d26ef7f_output.jsonl"))

(def output-c
  (read-jsonl "output/batch/msgbatch_01PGaff3EPbQJbpw6JeWoQR5_results.jsonl"))

(defn parse-json-with-comments [json-str]
  (let [mapper (doto (ObjectMapper.)
                 (.configure JsonParser$Feature/ALLOW_COMMENTS true)
                 (.configure JsonParser$Feature/ALLOW_SINGLE_QUOTES true)
                 (.configure JsonParser$Feature/ALLOW_UNQUOTED_FIELD_NAMES true))]
    (->(.readValue mapper json-str Object)
       (json/generate-string)
       (json/parse-string true))))

(defn get-json
  [message provider]
  (let [path (if (= "Anthropic" provider)
               [:result :message :content 0 :text]
               [:response :body :choices 0 :message :content])
        text (get-in message path)
        pattern #"\[(?s).*\]"]
    (try
      (parse-json-with-comments (re-find pattern text))
      (catch com.fasterxml.jackson.core.JsonParseException _ nil))))

(def json-b (mapv #(get-json % "OpenAI") output-b))

(def json-c (mapv #(get-json % "Anthropic") output-c))

;; compare expected vs returned ;; => true
(= (map (fn [[_ d]] (count d)) input-b (map count json-b)))
(= (map (fn [[_ d]] (count d)) input-c) (map count json-c))
