## Monitor Annotations

This is a scheduled job that checks annotations on any present files of active projects.
See https://github.com/nf-osi/jobs/issues/23.

It does the following:
- Query Study table for **active** projects and select relevant studyFileViews
- Check file entities in studyFileView
    - If no files, don't do anything
    - If files present, check for core required annotations (e.g. resourceType)
- Make list subset of files without any annotations
- Get user id(s) who uploaded the data
- Send email with list


### Secrets and env vars

```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=biweekly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

