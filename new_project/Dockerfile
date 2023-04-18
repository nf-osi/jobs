FROM ghcr.io/nf-osi/nfportalutils:develop@sha256:81960a3f76b69214d8060625aa808dc32790d35953dfa358ee4d12ce72de3c08


ARG USERNAME=nfosi
ARG USER_UID=1001
ARG USER_GID=1000

# Create the user
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo jq \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

WORKDIR /app

COPY new_project_from_json.R /new_project_from_json.R

ENTRYPOINT ["Rscript", "/new_project_from_json.R"]

