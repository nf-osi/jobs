## New Project

Create new project(s) given study JSON data (which follow the NF schema). 

### Example

See files under tests for examples of what these study data look like.
For testing, add `-e PROFILE=TEST` when running (see below). This will create the project but register it with the test Studies table instead of the real Studies table. 
Can create multiple studies at once, so: 
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project tests/study_1.json tests/study_2.json`



