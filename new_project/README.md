## New Project

Create a new project according to the NF template.

### Example

Use with FILE that is a JSON config.
`docker run -v "$(pwd)":/app -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN ghcr.io/nf-osi/jobs-new-project $FILE`

