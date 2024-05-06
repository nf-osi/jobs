import synapseclient
import pandas as pd
import os
import json
import argparse

# Constants for the views
FILE_VIEW_ID = "syn16858331"
PROJECT_VIEW_ID = "syn52677631"

def main(dry_run, update_df):
    syn = synapseclient.Synapse()
    secrets = json.loads(os.getenv("SCHEDULED_JOB_SECRETS"))
    auth_token = secrets["SYNAPSE_AUTH_TOKEN"]
    syn.login(authToken = auth_token)

    if update_df:
        print(f"Using manually specified data csv...")
        fileview_df = pd.read_csv(update_df)
    else:  
        # Fetch the project view data
        pending_projects_df = syn.tableQuery(f"SELECT id FROM {PROJECT_VIEW_ID} WHERE dataStatus='Data Pending'").asDataFrame()
        ids = tuple(pending_projects_df['id'])
        QUERY_IDS = f"({', '.join(repr(item) for item in ids)})"

        # Fetch the file view data
        # We'll need to filter out files created by nf-osi service or staff 
        # who tend to upload data sharing plans & other administrative files
        print(f"Checking production table for {len(ids)} projects with status 'Data Pending'...")
        fileview_df = syn.tableQuery(f"SELECT projectId,count(*) as N FROM {FILE_VIEW_ID} WHERE type='file' and createdBy not in ('3421893', '3459953', '3434950', '3342573') and projectId in {QUERY_IDS} group by projectId").asDataFrame()
    
    print(f"Found {len(fileview_df.index)} that qualifying for transition:")
    print(fileview_df)

    for idx, p in fileview_df.iterrows():
        project_to_update = syn.get(p['projectId'])
        print(f"Project {project_to_update['name']} has seen its first contribution of {p['N']} file(s)!")
        project_to_update['dataStatus'] = ['Under Embargo']
        if dry_run:
            print("Modified project meta (not stored):")
            print(project_to_update)
        else: 
            syn.store(project_to_update)
            print(f"Project {project_to_update['name']} had dataStatus changed to 'Under Embargo'")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true", help="Print project with modified metadata but do not store.")
    parser.add_argument("--update_df", type = str, help="Path to csv of projects to update.")
    args = parser.parse_args()
    main(dry_run = args.dry, update_df = args.update_df)
