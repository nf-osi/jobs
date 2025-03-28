(ns parse-outputs
  (:require [babashka.http-client :as http]
            [accent.state :refer [setup u]]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [curate.synapse :refer [new-syn syn set-annotations]]
            [json-schema.core :as json-schema])
  (:import [com.fasterxml.jackson.core JsonParser$Feature]
           [com.fasterxml.jackson.databind ObjectMapper]))

(defn read-jsonl
  "Reads a JSONL file, skipping invalid lines and returning valid JSON objects"
  [file-path]
  (with-open [rdr (io/reader file-path)]
    (doall
     (map #(json/parse-string % true)
            (line-seq rdr)))))

(def input-b (into {} (json/parse-string (slurp "input/batch/B.json") true)))

(def input-c (into {} (json/parse-string (slurp "input/batch/C.json") true)))

;; note that output order is NOT guaranteed same as input and should use custom ids
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
      {(keyword (message :custom_id)) (parse-json-with-comments (re-find pattern text))}
      (catch com.fasterxml.jackson.core.JsonParseException _ nil))))

(def json-b (into {} (mapv #(get-json % "OpenAI") output-b)))

(def json-c (into {} (mapv #(get-json % "Anthropic") output-c)))

(defn compare-counts
  "Compare expected vs returned"
  [input output]
  (- (count (vals input)) (count (vals output)))

(merge-with compare-counts input-b json-b)

(merge-with compare-counts input-c json-c)

(defn meta-map
  [input output]
  (let [datasets (mapcat (fn [[_ dataset]] dataset) input)
        dataset-ids (map :id datasets)
        metadata (mapcat identity output)]
    (zipmap dataset-ids metadata)))


(def b-datasets (meta-map input-b json-b))

(spit "b-datasets.edn" b-datasets)

(def c-datasets (meta-map input-c json-c))

(setup)

(new-syn (@u :sat))

(defn submit-meta
  "Takes input and output and applies annotations"
  [[dataset-id meta]]
  (set-annotations @syn dataset-id meta))

(def submissions (mapv submit-meta b-datasets))

(doseq [dataset b-datasets]
  (submit-meta dataset))
