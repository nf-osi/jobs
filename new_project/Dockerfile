FROM ghcr.io/nf-osi/nfportalutils:develop@sha256:103c21eea8c9a2c0e438880f28b03827e4285bc4e71f3141f5fdcf28a6b813ce

ARG USERNAME=nfosi
ARG USER_UID=1001
ARG USER_GID=1000

RUN apt-get update -qq && \
    apt-get install -y jq

# Create the user
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME

WORKDIR /app

COPY new_project_from_json.R /new_project_from_json.R

ENTRYPOINT ["Rscript", "/new_project_from_json.R"]

