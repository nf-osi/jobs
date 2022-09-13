## Monitor Annotations

This is a scheduled job that checks annotations on any present files of active projects.
See https://github.com/nf-osi/jobs/issues/23.

It does the following:
- Query Study table for **active** projects and select relevant studyFileViews
- Check file entities in studyFileView
    - If no files, don't do anything
    - If files present, check for core required annotations (e.g. assay)
- Make list subset of files without any annotations
- Get user id(s) who uploaded the data
- Send email with list


### Secrets and env vars

```
PROFILE=DEV # Or TEST for test and PROD for production
DCC_USER=3421893 # nf-osi-service / not needed for PROFILE=DEV
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=bimonthly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Testing Notes

- Build the image with e.g. docker build -t nfosi/jobs-monitor-anno . (or pull image -- to be auto-built soon)
- Create an envfile envfile-monitor-anno as above and run `docker run --env-file envfile-monitor-anno nfosi/jobs-monitor-anno`

