# projectlive-nf-data
Builds a docker image for data processing for the NF version of projectLive
[App repo](https://github.com/Sage-Bionetworks/projectLive_NF)

### Secrets and env vars


SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
LABEL=projectlive-nf-data
SCHEDULE=daily
COMMENT="Scheduled projectlive-nf-data"
SLACK=https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxxxxxxxxxx


### Example run 

`docker run --env-file envfile run ghcr.io/nf-osi/jobs-projectlive-nf-data:latest`