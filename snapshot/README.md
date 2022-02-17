## Snapshot

This is used in a scheduled job to batch version selected portal assets (tables and views, currently). 

### Secrets and env vars

```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
LABEL=snapshot
SCHEDULE=weekly
TARGETS="syn16787123,syn16858331"
COMMENT="Scheduled snapshot"
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

