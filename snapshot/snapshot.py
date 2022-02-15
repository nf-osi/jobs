import json, os, synapseclient, requests, traceback
from datetime import datetime

# Secrets
secrets = json.loads(os.getenv("SCHEDULED_JOB_SECRETS"))
auth_token = secrets["SYNAPSE_AUTH_TOKEN"]

# Table env vars & auto label
target_table = os.getenv("TABLE")
target_comment = os.getenv("COMMENT")
target_label = datetime.now()
job_label = os.getenv("LABEL")
print(f"Target table: {target_table}")

# Slack webhook to send notifications
slack = os.getenv("SLACK")

try:
    syn = synapseclient.Synapse()
    syn.login(authToken=auth_token)
    version = syn.create_snapshot_version(table=target_table, comment=target_comment, label=target_label)
    if slack is not None:
        txt = "Job (" + job_label + ") succeeded, updated to " + target_table + "." + str(
            version) + " just now. :thumbsup:"
        msg = json.dumps({"text": txt})
        r = requests.post(slack, data=msg, headers={'Content-type': 'application/json'})
        print(r.status_code)
except:
    traceback.print_exc()
    if slack is not None:
        txt = "Job (" + job_label + ") failed just now for " + target_table + " -- debug needed. :grimacing:"
        msg = json.dumps({"text": txt})
        r = requests.post(slack, data=msg, headers={'Content-type': 'application/json'})
        print(r.status_code)
