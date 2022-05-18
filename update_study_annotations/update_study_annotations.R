reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(httr)

# Values -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])

# Input/target tables
study_tab_id <- 'syn16787123'
portal_fileview_id <- 'syn16858331'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "update_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")

try({
    withCallingHandlers(
    {
      update_study_annotations(study_table_id = study_tab_id,
                               fileview_id = portal_fileview_id,
                               annotations = c("studyId","studyName","fundingAgency","initiative"),
                               dry_run = FALSE)
    }, 
    message = function(m) handleMessage(m, "main"),
    error = function(e) handleError(e, "main")
  )
})

slack_report(report)


