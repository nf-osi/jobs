## Jobs

Jobs and microservices for routine maintenance and reporting.

### Testing and development

#### General contribution flow

1. Create a new feature branch off `develop`.
2. Create a new directory for the job/service and put the script(s) and Dockerfile there.
3. Add a workflow to build an image (copy and adapt from current `.github/worflows`).
- Change `on.paths` so that the Docker build will build specifically for the job
- In the very last step, change `context` to the job directory
4. Make PR against `develop`.

#### How to interactively test and modify current jobs 

##### Jobs based on nfportalutils

These instructions use the `update_portal_tables` job as an example.   
(*For certain changes, nfportalutils may need to be updated rather than the script.)

1. Pull the nfportalutils image specified in the job's current Dockerfile or the image version that would be needed, e.g.
- `docker pull ghcr.io/nf-osi/nfportalutils:develop`
- `docker pull ghcr.io/nf-osi/nfportalutils@sha256:3b9777720f086308701ac1e960918c8727de85410d134228ed229425fb87e080`

2. Prepare an [env-file](https://docs.docker.com/compose/env-file/) with the required secrets and variables mentioned in the job's README, e.g.:
```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SCHEDULE=weekly
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

3. Clone/download the job script. Assuming your working directory contains the script and env-file, run the container:
`docker run -it -v $(pwd):/job --env-file envfile --entrypoint /bin/bash ghcr.io/nf-osi/nfportalutils:develop`

4. Go to where script has been mounted into the container and run it.
- `cd job`
- `r update_portal_tables.R`

5. Tweak the job script, e.g. fix some bug, change output messages, add subjobs, add downstream interoperability, etc., and rerun to test changes.
- `r update_portal_tables.R`

6. Commit new script and Dockerfile (if using new image), documenting any changes to secrets/variables the new script uses in the README, and create PR.



