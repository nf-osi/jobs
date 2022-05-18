reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(httr)

# Values -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])
study_tab_id <- 'syn16787123'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "calculate_related_studies"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")

try({
    withCallingHandlers(
    {
      calculate_related_studies(study_tab_id, n_clust = 40, dry_run = FALSE)
    }, 
    # message = function(m) handleMessage(m, "main"), # no useful messages currently
    error = function(e) handleError(e, "main")
  )
})

slack_report(report)


