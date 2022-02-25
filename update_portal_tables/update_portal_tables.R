reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(httr)

# Values -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])
study_tab_id <- 'syn16787123'
portal_fileview_id <- 'syn16858331'

# Jobs info
# Extract current schedule if available
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(
  subjob1 = paste(schedule, "calculate_related_studies"), # (target table: portal_studies)
  subjob2 = paste(schedule, "update_study_annotations"), # (target table: portal_files)
  subjob3 = paste(schedule, "assign_study_data_types") #  (target table: portal_studies)
)
# Store job outputs to transmit to notification system 
report <- lapply(job, function(x) paste(":white_check_mark:", x))

# Helper funs ------------------------------------------------------------------#

# Optional functionality to send slack report
# report = a list of messages
slack_report <- function(report) {
  if(Sys.getenv("SLACK") != "") {
    report <- list(text = paste(report, collapse = "\n"))
    slack_hook <- Sys.getenv("SLACK")
    report <- jsonlite::toJSON(report, auto_unbox = TRUE)
    post_status <- httr::POST(url = slack_hook, body = report, content_type_json())
    cat(post_status$status_code)
  } 
}

# The final error or message output will replace default report status 
handleError <- function(e, subjob) {
  report[[subjob]] <<- paste(":x:", job[[subjob]], " failed!")
  traceback()
}

handleMessage <- function(m, subjob) {
  report[[subjob]] <<- paste(":white_check_mark:", job[[subjob]], "- completed with message:", m$message)
}

# Main -------------------------------------------------------------------------#

tryCatch({
  # Subjob 1: Update related studies column
    withCallingHandlers(
    {
      calculate_related_studies(study_tab_id, n_clust = 30, dry_run = FALSE)
    }, 
    # message = function(m) handleMessage(m, "subjob1"), # no useful messages currently
    error = function(e) handleError(e, "subjob1")
  )
  
  # Subjob 2: Update file annotations that can be derived from study table
  withCallingHandlers(
    {
      update_study_annotations(study_table_id = study_tab_id,
                               fileview_id = portal_fileview_id,
                               annotations = c("studyId","studyName","fundingAgency","initiative"),
                               dry_run = FALSE)
    }, 
    message = function(m) handleMessage(m, "subjob2"),
    error = function(e) handleError(e, "subjob2")
  )
  
  # Subjob 3: Update study "data type" summary values
  withCallingHandlers(
    {
      data_types <- get_valid_values_from_json_schema("https://raw.githubusercontent.com/nf-osi/nf-metadata-dictionary/main/NF.jsonld")
      assign_study_data_types(study_table_id = study_tab_id,
                              fileview_id = portal_fileview_id,
                              valid_values = data_types,
                              dry_run = FALSE)
    }, 
    # message = function(m) handleMessage(m, "subjob3"), # no useful messages currently
    error = function(e) handleError(e, "subjob3")
  )},
  
  finally = slack_report(report)
)




