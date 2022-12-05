FROM ghcr.io/nf-osi/nfportalutils:develop@sha256:2efc3ce7986e96780340ef221e05cfbd8c763db07cf2fa270c62219e1e87bc67


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

