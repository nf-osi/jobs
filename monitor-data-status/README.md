## Monitor Data Status

This is a scheduled job that checks "Data Pending" projects for their first file contribution to change project data status to "Under Embargo". 
Files may not be immediately annotated with upload; therefore, see also "monitor annotations", which is concerned with annotations on files.
This job is intended to be run on service catalog.

### Secrets and env vars

- `SYNAPSE_AUTH_TOKEN`: (Required) This needs to have edit access to update the projects' annotations.


### Run params

- `--dry` By default, the job updates project in Synapse unless `--dry` is used for the run. 
- `--update_df` Use a csv to that directly specifies which projects should be updated, instead of querying the project view + file view. This is used for testing. Should have columns `projectId`, and `N`. 


### Testing

- Build the image with e.g. `docker build --no-cache -t ghcr.io/nf-osi/jobs-monitor-data-status .` (or pull current/pre-build image if available)
- Set up an `envfile-monitor-ds` with contents like below:

```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
```

- To run with `--dry`: `docker run --env-file envfile-monitor-ds ghcr.io/nf-osi/jobs-monitor-data-status --dry`
- To run without `--dry` but with test data: `sudo docker run --env-file envfile-monitor-ds --mount type=bind,source=$(pwd)/test.csv,target=/app/test.csv ghcr.io/nf-osi/jobs-monitor-data-status --update_df test.csv`
