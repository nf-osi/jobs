## Jobs

Jobs and microservices for routine maintenance and reporting.

## Testing and development

### General contribution flow for a *new* job

1. Create a branch off `develop` with prefix `feat/`.
2. Create a new directory for the job/service and put the script(s), Dockerfile, and job-specific README there.
3. Add a workflow to build an image (copy and adapt from current `.github/worflows`).
- Change `on.paths` so that the Docker build will build specifically for the job
- In the very last step, change `context` to the new job directory
4. (Optional) In your final commit, add `[pre-build]` in commit message if you want to provide a test image for the reviewers in the PR. 
5. Make PR against `develop` and add reviewer.

### Contributions to **existing** jobs

Create a branch off `develop` with prefix `patch/`, `fix/`, etc.
Ignore steps 2-4 because the directory and workflow will already exist.

### Testing

Here is how a job image is usually tested:

1. (a) `cd` into the job directory and build the image or
   (b) pull the image if it has been pre-built, e.g. with `[pre-build]` option mentioned above 

2. Prepare an [env-file](https://docs.docker.com/compose/env-file/) with the required secrets and variables mentioned in the job's README, e.g.:
```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=weekly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

3. Run the containerized job:
`docker run --env-file envfile ghcr.io/nf-osi/jobs-some-job`

Depending on the job, an additional command may need to be specified.
