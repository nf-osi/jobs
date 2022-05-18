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
job <- list(main = paste(schedule, "assign_study_data_types"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")

try({
    withCallingHandlers(
    {
      data_types <- get_valid_values_from_json_schema("https://raw.githubusercontent.com/nf-osi/nf-metadata-dictionary/main/NF.jsonld")
      assign_study_data_types(study_table_id = study_tab_id,
                              fileview_id = portal_fileview_id,
                              valid_values = data_types,
                              dry_run = FALSE)
    }, 
    # message = function(m) handleMessage(m, "main"), # no useful messages currently
    error = function(e) handleError(e, "main")
  )
})

slack_report(report)


