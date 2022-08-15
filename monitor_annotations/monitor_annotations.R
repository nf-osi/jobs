reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(data.table)
library(httr)

# Config -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])

# Check whether running as DEV, TEST or PROD, with default being DEV. Behavior for:
# PROD = Send out emails
# TEST = Send emails to nf-osi-service (3421893)
# DEV = Output emails to stout
profile <- switch(Sys.getenv("PROFILE"),
                  PROD = "PROD",
                  TEST = "TEST",
                  "DEV")
                  


# Input/target tables
study_tab_id <- 'syn16787123'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "monitor_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/e74a72ccebd8dc3480190c872b00ac5b8b6069ed/utils/slack.R")

#' Uses the returned fileview query to generate a list with 
#' `n` = Number of non-annotated files and 
#' `na_files` = List of non-annotated filenames organized by the file creator, e.g. 
#' `list(n = 3, na_files = list(`111` = c('team1_file1.csv', 'team2_file2.csv'), `222` = c('team2_file1.txt')))`. 
#' Many projects have more than one uploader, and it would be more understandable
#' to send individual, precise emails referencing only the relevant files for that user.
#' @param dt Table query result with `name`, `createdBy`, `resourceType`.
#' @param ignore_file File pattern to ignore.
#' @param ignore_user List of user ids to ignore. Defaults to NF service accounts. 
#' @param list_len Max length of list of files to return for each user. Default 50.
processNA <- function(dt,
                     ignore_file = "data sharing plan|synapse_storage_manifest|progress report",
                     ignore_user = c(3421893, 3423450), # nf-osi-service, nf-bot 
                     list_len = 50
                     ) {
  
  dt <- as.data.table(dt$asDataFrame())
  if(nrow(dt) == 0) return(list(n = 0, assigments = NULL))
  dt <- dt[!grepl(ignore, name, ignore.case = TRUE)][!createdBy %in% ignore_user]
  n <- dt[is.na(resourceType), .N]
  # Assemble list of creator ~ files for clear list of na_files
  na_files <- split(dt[is.na(resourceType)], by = "createdBy", keep.by = F)
  na_files <- sapply(na_files, function(x) paste0(head(x$name, list_len), " (", head(x$id, list_len), ")"))
  return(list(n = n, na_files = na_files))
}


#' Email reminder regarding annotation
#' @param user One or more synapse user ids
#' @param files A representative list of files assigned to the user to include in message.
#' @param project Optional project name or id for context (goes into message subject).
#' @param dcc The DCC Synapse profile id (numeric) to cc on the message. Use FALSE to not copy the DCC.  
#' @param dry_run If TRUE, output message instead of emailing. 
emailReAnnotation <- function(user,
                              files,
                              project = NULL, 
                              dcc = 3421893,
                              dry_run = TRUE
                              ) {
  msg_template <- 
  "Dear contributor,
  
  Our system shows you have uploaded files which are presently unannotated (some files appended below for reference). 
  NF-OSI encourages that data files be annotated according to the docs here: https://help.nf.synapse.org/NFdocs/how-to-annotate-data.
  You can ignore this reminder for any non-data files such as analyses and presentations.
  If you believe you have received this message in error, please contact nf-osi@sagebionetworks.org.
  
  Thank you,
  NF-OSI Service"
  
  msg_listing <- paste(files, collapse = "\n")
  
  msg_body <- paste0(msg_template,
                     "\n\n-----\n\n",
                     msg_listing,
                     "\n\n-----\n\n")
  
  msg_subj <- glue::glue("Please annotate files for Synapse project '{project}'")
    
  recipients <- if(dcc) c(user, dcc) else user
  recipients <- as.character(recipients)
  if(dry_run) {
    cat("to:", recipients, "\n",
        "subject:", msg_subj, "\n\n",
        msg_body)
  } else {
    .syn$sendMessage(userIds = recipients,
                     messageSubject = msg_subj, 
                     messageBody = msg_body,
                     contentType = "text/plain")
  }
}

#' Main wrapper to generate a list of assignments after processing the study table
#' @param study_tab_id
studyAssignments <- function(study_tab_id) {
  studies <- .syn$tableQuery(glue::glue("SELECT studyId,studyName,studyFileviewId from {study_tab_id} WHERE studyStatus='Active'"))
  studies <- studies$asDataFrame()
  
  for(fileview in studies$studyFileviewId) {
    # Issues to handle:
    # 1) Fileviews can break and be unquery-able, the most common error something like: 
    # 'attribute X size is too small, needs to be __'
    # 2) Columns in query for may be missing for some reason
    files[[fileview]] <- try(
      .syn$tableQuery(
        glue::glue("SELECT id,name,resourceType,createdBy from {fileview} WHERE type='file'")
      ))
  }
  
  # Use studyName instead of studyFileviewId as names
  names(files) <- studies$studyName
  
  fail <- names(which(sapply(files, class) == "try-error"))
  if(length(fail)) {
    files <- files[!names(files) %in% fail]
    warning("Encountered issues with some fileviews: ", paste(files, collapse = " "), call. = FALSE)
  }
  files <- lapply(files, processNA)
  # filter out n=0
  todo <- files[sapply(files, `[[`, 1) > 0] 
  todo <- lapply(todo, function(x) x$na_files)
  return(todo)
}


try({
    withCallingHandlers(
    {
      todo <- studyAssignments(study_tab_id) 
      for(project in names(todo)) {
        for(user in names(todo[[project]]) ) {
          emailReAnnotation(user = user, 
                            files = todo[[project]][[user]], 
                            project = project, 
                            dry_run = TRUE)
        }
      }
      
    }, 
    message = function(m) handleMessage(m, "main"),
    error = function(e) handleError(e, "main")
  )
})


slack_report(report)


