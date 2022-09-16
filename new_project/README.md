## New Project

Create a new project according to the NF template.

### Example

Use with one or more JSON config files.
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project config1.json config2.json`

