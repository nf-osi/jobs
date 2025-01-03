import synapseclient
import pandas as pd
import os
import json
import argparse
import requests
import traceback
import sys
from datetime import datetime

# Define the slack_report function
def slack_report(slack, success: bool, job_schedule, job_label, target, version=''):
    if success:
        txt = f":white_check_mark: {job_schedule} - {job_label} succeeded, {target} just now."

    else:
        txt = ":x: " + job_schedule + " - " + job_label + " failed just now for *" + target + "* :worried:"

    msg = json.dumps({"text": txt})
    r = requests.post(slack, data=msg, headers={'Content-type': 'application/json'})
    print(r.status_code)

# Load environment variables from an envfile
def load_envfile(envfile_path):
    with open(envfile_path) as f:
        for line in f:
            if line.strip() and not line.startswith('#'):
                key, value = line.strip().split('=', 1)
                os.environ[key] = value

def main(dry_run, update_df):
    syn = synapseclient.Synapse()
    secrets = json.loads(os.getenv("SCHEDULED_JOB_SECRETS"))
    auth_token = secrets["SYNAPSE_AUTH_TOKEN"]
    syn.login(authToken=auth_token)

    PROJECT_VIEW_ID = os.getenv("PROJECT_VIEW_ID")
    FILE_VIEW_ID = os.getenv("FILE_VIEW_ID")
    slack = os.getenv("SLACK")
    job_schedule = os.getenv("SCHEDULE")
    job_label = os.getenv("LABEL")

    try:
        if update_df:
            print(f"Using manually specified data csv...")
            fileview_df = pd.read_csv(update_df)
        else:  
            # Fetch the project view data
            pending_projects_df = syn.tableQuery(f"SELECT id FROM {PROJECT_VIEW_ID} WHERE dataStatus='Data Pending'").asDataFrame()
            ids = tuple(pending_projects_df['id'])
            QUERY_IDS = f"({', '.join(repr(item) for item in ids)})"

            print(f"Checking production table for {len(ids)} projects with status 'Data Pending'...")
            fileview_df = syn.tableQuery(f"SELECT projectId,count(*) as N FROM {FILE_VIEW_ID} WHERE type='file' and createdBy not in ('3421893', '3459953', '3434950', '3342573') and projectId in {QUERY_IDS} group by projectId").asDataFrame()

        print(f"Found {len(fileview_df.index)} that qualify for transition:")
        print(fileview_df)

        # Initialize a counter for successfully updated projects
        updated_count = 0

        for idx, p in fileview_df.iterrows():
            project_to_update = syn.get(p['projectId'])
            print(f"Project {project_to_update['name']} has seen its first contribution of {p['N']} file(s)!")
            project_to_update['dataStatus'] = ['Under Embargo']
            if dry_run:
                print("Modified project meta (not stored):")
                print(project_to_update)
            else:
                syn.store(project_to_update)
                updated_count += 1  # Increment count for successful updates
                print(f"Project {project_to_update['name']} had dataStatus changed to 'Under Embargo'")
        
        # Notify Slack of success
        slack_report(slack, success=True, job_schedule=job_schedule, job_label=job_label, target=f"{updated_count} projects updated")
    except Exception as e:
        traceback.print_exc()
        # Notify Slack of failure
        slack_report(slack, success=False, job_schedule=job_schedule, job_label=job_label, target="update_data_status")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true", help="Print project with modified metadata but do not store.")
    parser.add_argument("--update_df", type=str, help="Path to csv of projects to update.")
    parser.add_argument("--envfile", type=str, help="Path to the envfile containing environment variables.")
    args = parser.parse_args()

    if args.envfile:
        load_envfile(args.envfile)

    main(dry_run=args.dry, update_df=args.update_df)