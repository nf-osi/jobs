# projectlive-nf-data
Builds a docker image for data processing for the NF version of projectLive
This image is used in a scheduled job to update backend data files powering projectLive-NF. 
[App repo](https://github.com/Sage-Bionetworks/projectLive_NF)

### Secrets and env vars

Example envile
```
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Example run 

`docker run --env-file envfile run ghcr.io/nf-osi/jobs-projectlive-nf-data:latest`
