## Monitor Data Status

This is a scheduled job that checks "Data Pending" projects in Synapse for their first file contribution. When a contribution is detected, the project’s `dataStatus` is updated to "Under Embargo." This job is designed to ensure that projects transition correctly based on file contributions.

Files may not be immediately annotated after upload, so it's recommended to also use the "Monitor Annotations" job, which handles file annotation concerns. This job is intended to be run using a service catalog or similar job scheduler.

---

### Secrets and Environment Variables

Before running the job, ensure the required secrets and environment variables are set up. These include:

- `SYNAPSE_AUTH_TOKEN`: (Required) A Synapse personal access token with sufficient permissions to update projects' annotations. This token must have `edit` access to the targeted projects.
- `SCHEDULED_JOB_SECRETS`: A JSON-formatted string that includes the `SYNAPSE_AUTH_TOKEN`. Example:
  ```
  SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
  ```
- `SLACK`: The Slack webhook URL for sending notifications.
- `PROJECT_VIEW_ID`: Synapse ID of the project view to query "Data Pending" projects. Default: syn52677631
- `FILE_VIEW_ID`: Synapse ID of the file view to query file contributions. Default: syn16858331

Other optional environment variables:
- `SCHEDULE`: A label indicating the job schedule (e.g., "weekly").
- `LABEL`: A custom label for the job (e.g., "monitor-data-status").
- `COMMENT`: An optional comment to log job updates.

---

### Run Parameters

The following command-line parameters are available:

- `--dry`: (Optional) Runs the job in "dry-run" mode. This mode prints the changes that would be made without applying them to Synapse.
- `--update_df`: (Optional) Specifies the path to a CSV file that directly lists the projects to update. This is useful for testing. The CSV should include the following columns:
  - `projectId`: The ID of the project to update.
  - `N`: The number of files contributed.

---

### Testing and Running the Job

To build, test, and run the job using Docker, follow these steps:

#### 1. Build the Docker Image
Run the following command to build the Docker image:
```bash
docker build --no-cache -t ghcr.io/nf-osi/jobs-monitor-data-status .
```
Alternatively, you can pull the pre-built image if available.

#### 2. Set Up Environment Variables
Create an environment file (e.g., `envfile`) with the necessary variables:
```bash
SCHEDULED_JOB_SECRETS={"SYNAPSE_AUTH_TOKEN":"xxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
SLACK=https://hooks.slack.com/services/your/slack/webhook/url
PROJECT_VIEW_ID=synXXXXXX
FILE_VIEW_ID=synXXXXXX
LABEL=monitor-data-status
SCHEDULE=weekly
COMMENT="Automated data status monitoring"
```

#### 3. Run the Job
- **Dry-Run Mode**: To test the job without making any changes, run:
  ```bash
  docker run --env-file envfile ghcr.io/nf-osi/jobs-monitor-data-status --dry
  ```

- **Run with Test Data**: To test with a specific CSV file:
  ```bash
  docker run --env-file envfile --mount type=bind,source=$(pwd)/test.csv,target=/app/test.csv ghcr.io/nf-osi/jobs-monitor-data-status --update_df /app/test.csv
  ```

- **Full Run**: To run the job without the `--dry` flag and without test data, ensure the project and file views are configured correctly in the environment variables, then run:
  ```bash
  docker run --env-file envfile ghcr.io/nf-osi/jobs-monitor-data-status
  ```

---

### Slack Notifications

If a Slack webhook URL is provided via the `SLACK` environment variable, the job will send the following notifications:
- A success message when the job completes successfully.
- An error message if the job encounters an issue.

Notifications include details about the job schedule, label, and target.

---

Let me know if you need further refinements!