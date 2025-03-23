(ns curate-datasets
  (:require [accent.state :refer [setup]]
            [curate.synapse :refer [syn query-table label-access get-user-name get-entity-wiki]]
            [accent.chat :refer [ask save-messages reset-messages]]
            [agents.syndi :as syndi]
            [clojure.java.io :as io]
            [clojure.test :refer :all]
            [clojure.pprint :refer [pprint]]
            [clojure.string :as str]
            [cheshire.core :as json]
            [com.brunobonacci.mulog :as mu]))

(setup)

(def agentic-instructions
"You are given this curation assignment as one of our top-performing data assistants:

A project has one or more table(s) within the project, where each table represents a dataset.
Your goal is to create high-quality dataset metadata for these tables that conform to the JSON schema below.
Also below is pre-summarized information from the project and tables that can be used for forming accurate and useful metadata. If needed, you can also query the tables and use other tools to gather additional information or resolve inconsistencies, but balance metadata quality with efficient tool use.
Commit a minified JSON metadata record for each table entity.
When all tables have been processed, you can optionally use the 'send_feedback' tool to add a short summary of any issues or deficiencies regarding the data or schema for review.
When you are done, please send message \"DONE!\".")

(def batch-instructions
"You are given this curation assignment as one of our top-performing data assistants:

A project has one or more table(s) within the project, where each table represents a dataset.
Your goal is to create high-quality dataset metadata for these tables that conform to the JSON schema below.
Also below is pre-summarized information from the project and tables that can be used for forming accurate and useful metadata.")

(defn render-userid-result
  "Use for row results with coltype `USERID`"
  [client query-result]
  (->>(query-result :rows)
      (mapv #(try
              (get-user-name client (first %))
              (catch Exception e "?")))
     (str/join ", ")))

(defn render-query-result
  [client query-result]
  (cond
    (= "USERID" (first (query-result :coltypes))) (render-userid-result client query-result)
    :else (str/join ", " (apply concat (query-result :rows)))))

(defn make-queries
  [table-id]
  [ [:measurementTechnique "Assays" (str "SELECT distinct assay FROM " table-id)]
    [:species "Species" (str "SELECT distinct species FROM " table-id)]
    [:individualCount "Individual count" (str "SELECT count(distinct individualID) FROM " table-id)]
    [:specimenCount "Specimen count" (str "SELECT count(distinct specimenID) FROM " table-id)]
    [:diagnosis "Diagnoses present" (str "SELECT distinct diagnosis FROM " table-id)]
    [:tumorType "Tumor types present" (str "SELECT distinct tumorType FROM " table-id)]
    [:dataType "Data types" (str "SELECT distinct dataType FROM " table-id)]
    [:fileFormat "File formats present" (str "SELECT distinct fileFormat FROM " table-id)]
    [:funder "Funders" (str "SELECT distinct fundingAgency FROM " table-id)]
    [:contributor "Contains data created by" (str "SELECT distinct createdBy FROM " table-id)]
    [:files "Example files present" (str "SELECT name FROM " table-id " LIMIT 5")] ])

(defn pre-summarize
  [client table-id]
        ;; inferred-access (label-access client (first sample-files))
  (let [queries (make-queries table-id)]
    (for [[k label query] queries]
      (try
        (->>(query-table client table-id query)
            (render-query-result client)
            (str "- " label ": "))
        (catch Exception e
          (str "- " label ": ?"))))))


(defn as-markdown [input]
  (let [[project-id tables] input]
    (str "# Project ID: " project-id "\n\n"
         (get-entity-wiki @syn project-id) "\n\n"
         "## Tables for Curation\n"
         (str/join "\n\n"
           (map-indexed (fn [idx table]
                  (str (inc idx) ". ID: " (get table "id") "\n"
                       "Name: " (get table "name") "\n"
                       "Summary:\n"
                       (str/join "\n" (pre-summarize @syn (get table "id")))
                       "\n\n"))
                tables)))))

(defn make-prompt 
  [instructions schema data]
  (str instructions "\n\n"  
  "# JSON Schema\n"
  "```\n" 
  schema 
  "\n```\n\n" 
  (as-markdown data) "\n"))

(defn simulated-wrap-commit
  [{:keys [data entity_id collection_id product_name]}]
  (let [;; output (str data "\n")
        ]
    ;;(spit "commit_output.jsonl" output :append true)
    (if entity_id
      {:result "Commit successful." :type :success}
      {:result "Entity id is missing." :type :error})))

;; Watch for any content that is *not* "DONE!" that requires intervention
;; (add-watch syndi/openai-messages :chatlog-watcher
;;  (fn [_ _ _ new-state]
;;    (when (some #(= "DONE!" (:content %)) new-state)
;;      (let [log (with-out-str (pprint new-state))]
;;        (spit (str "logs/messages.edn") log)))))

(defn agentic-curation
  [instructions schema input batch-key batch-idx agent]
  (let [prompt (make-prompt instructions schema input)]
    (mu/log ::run-start :timestamp (System/currentTimeMillis) :batch batch-key :batch-idx batch-idx)
    (with-redefs [syndi/wrap-commit simulated-wrap-commit]
      (mu/with-context {:batch batch-key}
          (ask agent prompt)
        )
      (save-messages agent (str "runs/messages/" (name batch-key) "-" batch-idx ".edn"))
      (reset-messages agent))))

(defn read-batch-data
  [batch-key]
  (->>(get-in run-config [batch-key :input-data])
      (slurp)
      (json/parse-string)))

(def run-config
  {:A
   {:label "A-A"
    :input-data "input/agentic/A.json"
    :test-data "input/agentic/A-A.jsonl"
    :result-data "output/agentic/A-A.json"
    :schema "input/agentic/PortalDataset.json"
    :agent syndi/AnthropicSyndiAgent
    :provider "OpenAI"
    :model "gpt4-o"
    :agentic true}
   :B
   {:label "B-B"
    :input-data "input/batch/B.json"
    :test-data "input/batch/B-B.jsonl"
    :result-data "output/batch/B-B.json"
    :schema "input/batch/PortalDataset.json"
    :provider "OpenAI"
    :model "gpt4-o"
    :agentic false}
   :C
   {:label "B-C"
    :input-data "input/batch/C.json"
    :test-data "input/batch/B-C.jsonl"
    :result-data "output/batch/B-C.json"
    :schema "input/batch/PortalDataset.json"
    :provider "Anthropic"
    :model "claude-3-7-sonnet-20250219"
    :agentic false}
   :toy
   {:label "toy"
    :input-data "input/toy/data.json"
    :test-data "input/toy/toy.jsonl"
    :schema "input/batch/PortalDataset.json"
    :provider "OpenAI"
    :model "gpt4-o"
    :agentic false}
   })

(def system-prompt "You are Syndi, a highly competent and helpful data assistant.")

(defn add-to-anthropic-batch-dataset
  [dataset-file id text]
  (let [m {"custom_id" id
           "params" {
                "model" "claude-3-7-sonnet-20250219"
                "max_tokens" 6000
                "system" system-prompt
                "messages" [
                    {"role" "user"
                     "content" text}]
                     }
           }]
  (spit dataset-file (json/generate-string m) :append true)))

(defn add-to-openai-batch-dataset
  [dataset-file id text]
  (let [m {"custom_id" id
           "method" "POST"
           "url" "/v1/chat/completions"
           "body" {"model" "gpt-4o"
                   "messages" [{"role" "system"
                                "content" system-prompt}
                               {"role" "user"
                                "content" text}]
                   "max_tokens" 6000}}]
  (spit dataset-file (json/generate-string m) :append true)
  (println "Added data for " id)))

(defn delegate-batch-builder
  [provider dataset-file id text]
  (if (= "OpenAI" provider)
    (add-to-openai-batch-dataset dataset-file id text)
    (add-to-openai-batch-dataset dataset-file id text)))

(defn create-batch-dataset
  [batch-key]
  (let [input (read-batch-data batch-key)
        instructions batch-instructions
        schema (slurp (get-in run-config [batch-key :schema]))
        provider (get-in run-config [batch-key :provider])
        dataset-file (get-in run-config [batch-key :test-data])]
    (doseq [project input]
      (->>(make-prompt instructions schema project)
         (delegate-batch-builder provider dataset-file (project 0))))))

(defn run-batch!
  [{:keys [batch-id]}]
  (let [batch-key (keyword batch-id)
        batch-data (read-batch-data batch-key)
        agent (get-in run-config [batch-key :agent])
        project-root (System/getProperty "user.dir")
        log-dir (str project-root "/runs/")]
  (println "Logging will use " log-dir)
  (mu/start-publisher! {:type :simple-file :filename (str log-dir "batch-" (name batch-key) ".log")})
  (doseq [[idx input] (map-indexed vector batch-data)]
    (println (str "Processing project " (inc idx) " of " (count batch-data)))
    (agentic-curation input batch-key idx agent))))
