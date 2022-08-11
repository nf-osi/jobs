reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(data.table)
library(httr)

# Values -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
syn_login(authtoken = secrets[["SYNAPSE_AUTH_TOKEN"]])

# Input/target tables
study_tab_id <- 'syn16787123'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "monitor_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")

# Filter for non-annotated files
#' @param dt Data.table with props `name`, `createdBy`, `resourceType`
#' @param ignore_file File pattern to ignore.
#' @param ignore_user List of user ids to ignore. Defaults to NF service accounts.
#' @param list_len Max length of list of files to return for each user. Default 50.
processNA <- function(dt,
                     ignore_file = "data sharing plan|synapse_storage_manifest|progress report",
                     ignore_user = c(3421893, 3423450), # nf-osi-service, nf-bot
                     list_len = 50
                     ) {
  
  if(nrow(dt) == 0) return(list(n = 0, assigments = NULL))
  dt <- dt[!grepl(ignore, name, ignore.case = TRUE)][!createdBy %in% ignore_user]
  n <- dt[is.na(resourceType), .N]
  # Assemble list of creator ~ files for clear list of assignments
  assignments <- split(dt[is.na(resourceType), .(files = first(name, list_len)), by = createdBy], 
                       by = "createdBy", keep.by = F)
  return(list(n = n, assignments = assignments))
}

# Wrapper helper
checkNA <- function(files) {
  result <- lapply(files, processNA)
  result <- result[sapply(result, `[[`, 1) > 0] # filter out n=0
  return(result)
}


#' Email reminder regarding annotation
#' @param user One or more synapse user ids
#' @param files A representative list of files assigned to the user to include in message.
#' @param project Optional project name or id for context (goes into message subject).
#' @param dcc The DCC Synapse profile id (numeric) to cc on the message. Use FALSE to not copy the DCC.   
emailReAnnotation <- function(user, 
                               files,
                               project = NULL, 
                               dcc = FALSE
                                ) {
  msg_template <- 
  "Dear contributor,
  
  Our system shows you have uploaded files which are presently unannotated (see some files apppended below for reference). 
  NF-OSI encourages that data files be annotated according to the docs here: https://help.nf.synapse.org/NFdocs/how-to-annotate-data.
  You can ignore this reminder for any non-data files such as analyses and presentations.
  If you think you have received this message in error, please contact nf-osi@sagebionetworks.org.
  
  Thank you,
  NF-OSI Service"
  
  msg_append <- paste(files, collapse = "\n")
  
  msg_body <- paste0(msg_template,
                     "\n\n-----\n\n",
                     msg_append)
  
  msg_subj <- glue::glue("Please annotate files you've deposited for Synapse project {project}")
    
  recipients <- if(dcc) c(user, dcc) else user
  recipients <- as.character(recipients)
  success <- .syn$sendMessage(userIds = recipients, 
                              messageSubject = msg_subj, 
                              messageBody = msg_body,
                              contentType = "text/plain")
}


try({
    withCallingHandlers(
    {
      dt <- .syn$tableQuery(glue::glue("SELECT studyId,studyFileviewId from {study_tab_id} WHERE studyStatus='Active'"))
      dt <- dt$asDataFrame()
      
      for(fileview in dt$studyFileviewId) {
        # Issues to handle:
        # 1) Fileviews can break and be unquery-able, the most common error something like: 'attribute X size is too small, needs to be __'
        # 2) Columns in query for may be missing for some reason
        files[[fileview]] <- try(
          .syn$tableQuery(
            glue::glue("SELECT id,name,resourceType,createdBy from {fileview} WHERE type='file'")
          ))
      }
      
      fail <- names(which(sapply(files, class) == "try-error"))
      if(length(fail)) {
        files <- files[!names(files) %in% fail]
        message("Encountered issues with some fileviews: ", paste(files, collapse = " "))
      }
      files <- lapply(files, function(x) as.data.table(x$asDataFrame()))
      todo <- checkNA(files)
      assignments <- lapply(todo, function(x) x$assignments)
      for(project in names(assignments)) {
        for(user in names(assignments[[project]]) ) {
          emailReAnnotation(user = user, files = assignments[[project]][[user]], project = project)
        }
      }
      
    }, 
    message = function(m) handleMessage(m, "main"),
    error = function(e) handleError(e, "main")
  )
})


slack_report(report)


