## New Project

Create new project(s) given study JSON data following the [NF schema](). 

### Examples

See files under tests for examples of what these study data look like.
For testing, add `-e PROFILE=TEST` when running (see below). This will create the project but register it with the [test fixture Studies table](https://www.synapse.org/#!Synapse:syn27353709/tables/) instead of the production Studies table.

#### Test

Single study:
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN -e PROFILE=TEST ghcr.io/nf-osi/jobs-new-project tests/study_basic.json`

Multiple studies:
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN -e PROFILE=TEST ghcr.io/nf-osi/jobs-new-project tests/study_two_datasets.json tests/study_same_data_labels.json`

