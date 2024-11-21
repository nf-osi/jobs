## Snapshot

This is used in a scheduled job to batch version selected portal assets (tables and views, currently). 

### Secrets and env vars

```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
LABEL=snapshot
SCHEDULE=weekly
COMMENT="Scheduled snapshot"
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Example build

`docker build -t ghcr.io/nf-osi/jobs-snapshot .`

See images with `docker image ls`

### Example run 

Note: replace the ids with your own test entities in case the example tables no longer exist

`docker run --env-file envfile ghcr.io/nf-osi/jobs-snapshot syn51907919 syn25585549`

### To do

- Configure for other app webhooks, i.e. if something else needs to happen after snapshot
- Better login checks

