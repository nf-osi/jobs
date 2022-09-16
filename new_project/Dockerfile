FROM ghcr.io/nf-osi/nfportalutils:develop

WORKDIR /app

RUN apt-get -y update && apt-get install -y jq

COPY new_project_from_json.R /new_project_from_json.R

ENTRYPOINT ["Rscript", "/new_project_from_json.R"]

