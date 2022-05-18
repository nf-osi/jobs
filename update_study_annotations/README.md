## Update Study Annotations

This is a scheduled job that annotates files with some parent attributes, e.g. study name and funding agency.
This allows files to be faceted by those properties. 
If/when these parent properties can be inherited automatically, this job can be decommissioned. 

### Secrets and env vars

```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=weekly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

