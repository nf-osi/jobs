(ns openai.batch
  (:require [babashka.http-client :as http]
            [accent.state :refer [setup u]]
            [cheshire.core :as json]
            [clojure.java.io :as io]))

(setup)

(def file (io/file "input/batch/B-B.jsonl"))

(def file-resp 
  (http/post "https://api.openai.com/v1/files"
   {:headers {"Authorization" (str "Bearer " (@u :oak))}
    :multipart [{:name "purpose"
                 :content "batch"}
                {:name "file"
                 :content file }]
    }))

(def file-id "file-HtdGoe1Y8Q1YjLFeN1U6g8")

(defn create-batch
  [input-file-id]
  (let [request-body {:input_file_id input-file-id
                      :endpoint "/v1/chat/completions"
                      :completion_window "24h"}]
    (http/post "https://api.openai.com/v1/batches"
               {:headers {"Authorization" (str "Bearer " (@u :oak))
                          "Content-Type" "application/json"}
                :body (json/encode request-body)})))

(def batch-resp (create-batch file-id))

(def batch (json/parse-string (batch-resp :body)))

(def batch-id "batch_67df5faa13f08190b9a130d96d26ef7f")

(defn check-batch
  [batch-id]
  (http/post (str "https://api.openai.com/v1/batches/" batch-id)
             {:headers {"Authorization" (str "Bearer" (@u :oak))
                        "Content-Type" "application/json"}}))
