## New Project

Create new project(s) based on study data following the [NF study schema](https://github.com/nf-osi/dcc-site/blob/main/lib/study-schema.json). 

### Examples

See files under tests for examples of what these study data look like.

#### Test

Single study:
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project tests/study_basic.json`

Multiple studies:
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project tests/study_two_datasets.json tests/study_same_data_labels.json`

