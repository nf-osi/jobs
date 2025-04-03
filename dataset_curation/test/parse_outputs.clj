(ns parse-outputs
  (:require [babashka.http-client :as http]
            [accent.state :refer [setup u]]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [curate.synapse :refer [new-syn syn set-annotations]]
            [json-schema.core :as json-schema])
  (:import [com.fasterxml.jackson.core JsonParser$Feature]
           [com.fasterxml.jackson.databind ObjectMapper]))

;;;;;;;;;;
;; Inputs
;; ;;;;;;
(defn read-jsonl
  "Reads a JSONL file, skipping invalid lines and returning valid JSON objects"
  [file-path]
  (with-open [rdr (io/reader file-path)]
    (doall
     (map #(json/parse-string % true)
            (line-seq rdr)))))

(defn read-input
  [file]
  (into {} (json/parse-string (slurp file) true)))

(def input-b (read-input "input/batch/B.json"))

(def input-c (read-input "input/batch/C.json"))

(def input-g (read-input "input/batch/A.json")) ;; shared with A

(def all-inputs (merge input-b input-c input-g))

;;;;;;;;;;;;;;;;;;;;;
;; Outputs
;; note that output order is NOT guaranteed same as input and should use custom ids
;;;;;;;;;;;;;;;;;;;;


(def schema (json-schema/prepare-schema
             (-> "input/batch/PortalDataset.json"
                 slurp
                 (json/parse-string true))))

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
  (let [path (case provider
               "Anthropic" [:result :message :content 0 :text]
               "OpenAI" [:response :body :choices 0 :message :content]
               "Google" [:candidates 0 :content :parts 0 :text])
        text (get-in message path)
        pattern #"\[(?s).*\]"]
    (re-find pattern text)))

(defn process-result
  [message provider logfile]
  (let [k (keyword (message :custom_id))]
    (try
      (->>(get-json message provider)
          (json-schema/validate schema)
          (parse-json-with-comments)
          (hash-map k))
      (catch com.fasterxml.jackson.core.JsonParseException _
        (do
          (spit logfile {:id k
                              :parse_errors true
                              :provider provider}
                :append true)
          {k nil}))
      (catch Exception e
        (do
          (spit logfile {:id k
                              :validation_errors (:errors (ex-data e))
                              :provider provider}
                :append true)
          {k nil})))))

(defn process-result-file
  [file provider logfile]
  (->>(read-jsonl file)
      (mapv #(process-result % provider logfile))
      (into {})))

;; Stage 1
(def b
  (process-result-file "output/batch/batch_67df5faa13f08190b9a130d96d26ef7f_output.jsonl" "OpenAI" "stage1.log"))

(def c
  (process-result-file "output/batch/msgbatch_01PGaff3EPbQJbpw6JeWoQR5_results.jsonl" "Anthropic" "stage1.log"))

(def g
  (process-result-file "output/batch/batch_gemini-2.5-pro-exp-03-25.jsonl" "Google" "stage1.log"))



;; Stage 2
(def b2 (process-result-file "output/batch2/batch_67eb6b318eac81909bd3708f50cb1bf0_output.jsonl" "OpenAI" "stage2.log"))

(def c2 (process-result-file "output/batch2/msgbatch_0122xH2Y9pK4xeLMqX3RBvqv_results.jsonl" "Anthropic" "stage2.log"))

(def g2 (process-result-file "output/batch2/batch_gemini-2.5-pro-exp-03-25.json.jsonl" "Google" "stage2.log"))


;;;;;;;;;;;;;;;;;;;;;;
;; Compare / validate
;; ;;;;;;;;;;;;;;;;;;;

(defn compare-counts
  "Compare expected vs returned"
  [input-val output-val]
  (if output-val
    (- (count output-val) (count input-val))
    (- (count input-val))))

(def b-stats (merge-with compare-counts input-b b))

(def c-stats (merge-with compare-counts input-c c))

(def g-stats (merge-with compare-counts input-g g))

(def b2-stats (merge-with compare-counts all-inputs b2))

(def c2-stats (merge-with compare-counts all-inputs c2))

(def g2-stats (merge-with compare-counts all-inputs g2))

(defn meta-map
  [input output]
  (let [datasets (mapcat (fn [[_ dataset]] dataset) input)
        dataset-ids (map :id datasets)
        metadata (mapcat identity output)]
    (zipmap dataset-ids metadata)))

(defn sum-score [stats-map] (reduce + (vals stats-map)))

(defn percent-of-projects
  [stats-map]
  (let [all-values (vals stats-map)
        total-count (count all-values)]
    (if (zero? total-count)
      {:zero 0.0, :negative 0.0}
      (let [zero-count (count (filter zero? all-values))
            negative-count (count (filter neg? all-values))
            zero-proportion (/ (double zero-count) total-count)
            negative-proportion (/ (double negative-count) total-count)]
        {:zero zero-proportion
         :negative negative-proportion}))))

(defn accounting
  [val1 val2]
  (let [v1 (cond
             (neg? val1) 1
             (= 0 val1) 0
             :else val1)
        v2 (if (neg? val2) 1 0)]
    (+ v1 v2)))

(defn common-failures
  [stats-maps]
  (let [negative-counts (apply merge-with accounting stats-maps)]
    {:two-of-three   (->> negative-counts
                          (filter (fn [[_k count]] (= count 2)))
                          (map key)
                          (set))
     :three-of-three (->> negative-counts
                          (filter (fn [[_k count]] (= count 3)))
                          (map key)
                          (set))}))

(def fails (common-failures [b2-stats c2-stats g2-stats]))

(def excluded (into #{} cat (vals fails)))

(defn remove-projects [result] (reduce dissoc result excluded))

(def final (mapv #(remove-projects %) [b2 c2 g2]))

(defn merge-input-result-vals
  "val1 is expected to be all-inputs and val2 the result"
  [val1 val2]
  (let [ids-only (mapv #(select-keys % [:id]) val1)]
  (mapv #(merge %1 %2) ids-only (concat val2 (repeat {})))))

(def results
  (for [result [b2 c2 g2]]
    (->>(merge-with merge-input-result-vals all-inputs result)
        (remove (comp (fails :three-of-three) first))
        (mapcat val)
        )))

(spit "results.json" (json/generate-string (zipmap ["cardsA" "cardsB" "cardsC"] results)))

(setup)

(new-syn (@u :sat))

(defn submit-meta
  "Takes input and output and applies annotations"
  [[dataset-id meta]]
  (set-annotations @syn dataset-id meta))

(def submissions (mapv submit-meta b-datasets))

(doseq [dataset b-datasets]
  (submit-meta dataset))
