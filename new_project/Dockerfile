FROM ghcr.io/nf-osi/nfportalutils:develop@sha256:cd3434cdb4ebbfd68f3671ee6116fc7e6b06a0c6d34a74dcb1ebbfd345a1b282

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

