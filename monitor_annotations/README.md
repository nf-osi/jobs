## Monitor Annotations

This is a scheduled job that checks annotations on any present files of active projects.
See https://github.com/nf-osi/jobs/issues/23.

It does the following:
- Query Study table for **Active** projects and goes through their studyFileViews
- How each studyFileView is checked:
    - If no files, don't do anything
    - If files present, check for core required annotations (e.g. `assay`)
- Reference which folders have files without required annotations
- Get user id(s) who uploaded the data
- Send email to user with folders referenced


### Secrets and env vars

#### Profiles

- `DEV`: print emails to stdout
- `TEST`: send emails to `TEST_USER` only
- `PROD`: send emails to real user OR (real user + cc the DCC if `DCC_USER` is provided) 

With `PROFILE=TEST`, you *must* provide an id for `TEST_USER`.
With `PROFILE=PROD`, you *may* provide a `DCC_USER` for which to cc the messages sent.

#### Optional 

- `SCHEDULE`: Used for message display labels only.
- `SLACK`: Slack channel webhook to report basic job status.
- `DIGEST_SUBSCRIBERS`: Semicolon-delimited Synapse user ids who want to receive an additional summary table to their email.


```
PROFILE=DEV # Or TEST for test and PROD for production
DCC_USER=3421893 # nf-osi-service
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=monthly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
DIGEST_SUBSCRIBERS=1111111;2222222
```

### Testing Notes

#### With Docker image

- Build the image with e.g. `docker build -t ghcr.io/nfosi/jobs-monitor-annotations .` (or pull current/pre-build image if available)
- Create an envfile `envfile-monitor-anno` as above and run `docker run --env-file envfile-monitor-anno ghcr.io/nf-osi/jobs-monitor-annotations`

#### Unit tests

- See tests in `tests` folder