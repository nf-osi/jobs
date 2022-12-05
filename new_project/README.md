## New Project

Create a new project according to the NF template.

### Example

Use with one or more JSON config files.
For testing, add `-e PROFILE=TEST` when running (see below). This will create the project but register it with the test Studies table instead of the real Studies table. 
Assuming that the current working directory contains two files `config1.json` `config2.json`:
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project config1.json config2.json`



