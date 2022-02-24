import json, os, synapseclient, requests, traceback
from datetime import datetime

# Secrets
secrets = json.loads(os.getenv("SCHEDULED_JOB_SECRETS"))
auth_token = secrets["SYNAPSE_AUTH_TOKEN"]

# Define parameters from environment vars
# Currently targets refer to tables & views, but may be other versionable assets in future
targets = os.getenv("TARGETS") 
target_comment = os.getenv("COMMENT")
target_label = datetime.now()
job_schedule = os.getenv("SCHEDULE")
job_label = os.getenv("LABEL")
slack = os.getenv("SLACK") # Slack webhook to send notifications

# Targets could be multiple and need to be parsed
targets = targets.split(" ")
print(f"Targets: {targets}")

def slack_report(slack, success:bool, job_schedule, job_label, target, version):
    if success:
        txt = ":white_check_mark: " + job_schedule + " - " + job_label + " succeeded, updated to *" + target + "." + str(
                version) + "* just now."
    else:
        txt = ":x: " + job_schedule + " - " + job_label + " failed just now for *" + target + "* :worried:"
    
    msg = json.dumps({"text": txt})
    r = requests.post(slack, data=msg, headers={'Content-type': 'application/json'})
    print(r.status_code)

# Login
# Need to handle login fails
syn = synapseclient.Synapse()
syn.login(authToken=auth_token)

# Iterate   
for target in targets:
    try:
        version = syn.create_snapshot_version(table=target, comment=target_comment, label=target_label)
        if slack is not None:
            slack_report(slack, success=True, job_schedule=job_schedule, job_label=job_label, target=target, version=version)
    except:
        traceback.print_exc()
        if slack is not None:
            slack_report(slack, success=False, job_schedule=job_schedule, job_label=job_label, target=target)


