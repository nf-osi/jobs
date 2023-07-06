reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(data.table)
library(httr)

# Config -----------------------------------------------------------------------#

# Check whether running as DEV, TEST or PROD, with DEV being default and catch-all. Behavior for:
# PROD = Send emails to actual users
# TEST = Send emails to nf-osi-service (3421893)
# DEV = Print emails to stout and save in messages.log only
PROFILE <- switch(Sys.getenv("PROFILE"),
                  PROD = "PROD",
                  TEST = "TEST",
                  "DEV")

cat("PROFILE:", PROFILE, "\n")

# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])

DCC_USER <- Sys.getenv("DCC_USER")
TEST_USER <- as.character(Sys.getenv("TEST_USER"))

if(PROFILE == "TEST" && TEST_USER == "") error("For PROFILE=TEST you must set TEST_USER=xxx")

DRY_RUN <- if(PROFILE == "DEV") TRUE else FALSE 
SLEEP_INTERVAL <- 6 # seconds

# Reference tables
study_tab_id <- 'syn16787123'
fileview_tab_id <- 'syn16858331'
no_email_list <- 'syn51907919'

no_email_list_users <- as.character(unlist(table_query(no_email_list, columns = "user"), use.names = FALSE))

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "monitor_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/e74a72ccebd8dc3480190c872b00ac5b8b6069ed/utils/slack.R")
source("helpers.R")

try({
    withCallingHandlers(
    {
      todo <- make_active_study_reminder_list(study_tab_id, fileview_tab_id)
      if(DRY_RUN) sink("messages.log", append = TRUE, split = TRUE)
      for(project in names(todo)) {
        for(user in names(todo[[project]][["naf"]]) ) {
          # Check user against no-email-list
          if(user %in% no_email_list_users) {
            
            message("Skipping reminder for: ", user)
            
          } else {
            
            TEST_USER <- if(PROFILE == "TEST") TEST_USER else NULL
            email_re_annotation(recipient = user, 
                                list = todo[[project]][["naf"]][[user]],
                                type = "folder",
                                project = project,
                                test_user = TEST_USER,
                                dcc = DCC_USER,
                                dry_run = DRY_RUN)
            cat("Email composed for:", user, "\n")
            Sys.sleep(SLEEP_INTERVAL)
            
          }
        }
      }
      
    }, 
    warning = function(w) handleWarning(w, "main"),
    error = function(e) handleError(e, "main")
  )
  
  # Create and send digest
  if(Sys.getenv("DIGEST_SUBSCRIBERS") != "") {
    digest_recipients <- as.list(strsplit(Sys.getenv("DIGEST_SUBSCRIBERS"), ";")[[1]])
    table_digest <- data.table(Project = names(todo), 
                               NAF = sapply(todo, `[[`, "n"), 
                               Users = sapply(todo, function(x) glue::glue_collapse(names(x[["naf"]]), " ")))
    html_digest <- print(xtable::xtable(table_digest), type = "html", html.table.attributes = "border='1px solid gray' cellpadding='6' cellspacing='0'", print.results = FALSE)
    .syn$sendMessage(digest_recipients, 
                     messageSubject = glue::glue("{schedule} digest for monitor annotations"), 
                     messageBody = html_digest, 
                     contentType = "text/html")
  }
})


slack_report(report)


