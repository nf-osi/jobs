reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(data.table)
library(httr)

# Config -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])

# Check whether running as DEV, TEST or PROD, with DEV being default and catch-all. Behavior for:
# PROD = Send emails to actual users
# TEST = Send emails to nf-osi-service (3421893)
# DEV = Print emails to stout
PROFILE <- switch(Sys.getenv("PROFILE"),
                  PROD = "PROD",
                  TEST = "TEST",
                  "DEV")
                  
DCC_USER <- 3421893 # nf-osi-service
DRY_RUN <- if(PROFILE == "DEV") TRUE else FALSE 

# Input/target tables
study_tab_id <- 'syn16787123'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "monitor_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/e74a72ccebd8dc3480190c872b00ac5b8b6069ed/utils/slack.R")
source("helpers.R")

try({
    withCallingHandlers(
    {
      todo <- studyAssignments(study_tab_id) 
      for(project in names(todo)) {
        for(user in names(todo[[project]][["na_files"]]) ) {
          # Override actual USER for TEST
          if(PROFILE == "TEST") user <- DCC_USER
          emailReAnnotation(user = user, 
                            files = todo[[project]][["na_files"]][[user]], 
                            project = project, 
                            dry_run = DRY_RUN)
        }
      }
      
    }, 
    warning = function(w) handleWarning(w, "main"),
    error = function(e) handleError(e, "main")
  )
})


slack_report(report)


