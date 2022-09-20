FROM ghcr.io/nf-osi/nfportalutils@sha256:3b9777720f086308701ac1e960918c8727de85410d134228ed229425fb87e080

COPY monitor_annotations.R /monitor_annotations.R
COPY helpers.R /helpers.R

ENTRYPOINT ["r", "/monitor_annotations.R"]

