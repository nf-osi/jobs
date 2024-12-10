FROM ghcr.io/nf-osi/nfportalutils:latest

ARG USERNAME=nfosi
ARG USER_UID=1001
ARG USER_GID=1000

RUN apt-get update && \
    apt-get install -y jq

# Create the user
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME

WORKDIR /app

COPY new_project_from_json.R /new_project_from_json.R

ENTRYPOINT ["Rscript", "/new_project_from_json.R"]

