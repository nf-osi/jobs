# Helpers for `monitor_annotations.R`

# QUERY ------------------------------------------------------------------------#

#' Retrieve active studies from Portal - Studies
#' 
#' @param study_tab_id Study table id.
#' @param verbose
#' 
get_active_studies <- function(study_tab_id) {
  studies <- .syn$tableQuery(glue::glue("SELECT studyId,studyName from {study_tab_id} WHERE studyStatus='Active'"))
  studies <- studies$asDataFrame()
  return(studies)
}

#' Query Portal - Files for newish un-annotated files for active studies
#' 
#' See `crawl_active_fileviews` for related implementation.
#' @param study_id Char vector of study id(s). 
query_file_attributes <- function(study_id, fileview_tab_id) {
  study_id <- glue::glue_collapse(shQuote(study_id, type = "sh"), ",")
  file_attributes <- try(
    .syn$tableQuery(
      glue::glue("SELECT id,name,resourceType,parentId,projectId,createdBy,createdOn from {fileview_tab_id} WHERE type='file' AND projectId in ({study_id}) AND (resourceType is null OR assay is null)")
    )
  )
}

#' Translate ids to names
#' 
#' Mainly used to get names of folders
ids_to_names <- function(ids) {
  names <- sapply(ids, function(x) .syn$get(x)$properties$name)
  return(names)
}


#' FILTERS ---------------------------------------------------------------------#

#' Returns subset based on past date cutoff
#' 
#' Even when considering only "Active" studies, there might be files older than a year that are un-annotated. 
#' To avoid user cognitive overload, we can fine tune to the new-ish files using `within_days`. 
#' 
#' MUST provide `createdOn` for the files.
filter_by_date <- function(files, within_days = 365) {
  cutoff_date <- Sys.Date() - within_days
  files[, createdOn := lubridate::as_datetime(createdOn / 1000)]
  files <- files[createdOn > cutoff_date]
  return(files)
}

#' Returns subset excluding inferred non-data files based on file name globbing
#' 
#' MUST provide `name` for the files. Ignores case.
filter_by_glob <- function(files, glob = "^DSP|data sharing plan|synapse_storage_manifest|.*report|\\.pdf$|\\.docx?$|\\.pptx?$|_annotation\\.csv|md5$") {
  files <- files[!grepl(glob, name, ignore.case = TRUE)]
  return(files)
}

#' Exclude inferred non-data files based on file name globbing
#' 
#' MUST provide `resourceType` for the files.
filter_by_type <- function(files, type = c("curatedData", "result", "tool", "report", "metadata", "protocol", "workflow report")) {
  files <- files[!resourceType %in% type]
  return(files)
}

#' Returns subset excluding certain user creators
#' 
#' MUST provide `createdBy` for the files.
filter_by_user <- function(files, user = c(DCC_USER)) {
  files <- files[!createdBy %in% user]
  return(files)
}

# UTILS ------------------------------------------------------------------------#

as_syn_link <- function(name, id, label = " ") {
  glue::glue('<a target="_blank" href="https://www.synapse.org/#!Synapse:{id}">{label}{name}</a><br/>')
}

# EMAIL/MESSAGING --------------------------------------------------------------#

#' Email reminder regarding annotation
#' @param recipient One or more synapse user ids
#' @param list A list of files or folders assigned to the user to include in message.
#' @param personalize Whether to look up and use user names instead of more standard addressee label.
#' Note tradeoffs between speed and nicer messages.
#' @param type Type of list; merely changes the wording.
#' @param project Optional project name or id for context (goes into message subject).
#' @param test_user If test user is given, message is sent to test user.
#' @param dcc The DCC Synapse profile id (numeric) to cc on the message. Default NULL.  
#' @param dry_run If TRUE, output message instead of emailing. 
email_re_annotation <- function(recipient,
                                list,
                                personalize = TRUE,
                                type = "folder",
                                project = NULL, 
                                test_user = NULL,
                                dcc = NULL,
                                dry_run = TRUE
) {
  
  if(personalize) {
    uprofile <- .syn$getUserProfile(recipient)
    addressee <- paste(uprofile$firstName, uprofile$lastName) 
  } else {
    addressee <- "NF Data Portal contributor"
  }
  details <- if(type == "folder") "in the folders" else "as a representative selection" 
  msg_template <- glue::glue( 
    'Dear {addressee},
    <br/><br/>
    Please annotate files that you have uploaded to this project in Synapse.
    The files which need annotation are listed {details} below.
    NF-OSI encourages (and many NF funders mandate) that data files be annotated so that they and future data users can understand the data.
    At minimum please provide “resourceType”, “dataType”, “specimenID” and “assay” to help make the data findable. 
    You can find annotation instructions <a target="_blank" href="https://help.nf.synapse.org/NFdocs/how-to-annotate-data">here</a>.
    If you need help, feel free to reach out to us at nf-osi@sagebionetworks.org.
    <br/><br/>
    Thank you,
    <br/>
    NF-OSI Service')
  
  msg_listing <- paste(list, collapse = "\n")
  
  msg_body <- paste0(msg_template,
                     "<br/><br/><hr/><br/>",
                     msg_listing,
                     "<br/><hr/><br/>")
  
  msg_subj <- glue::glue("Please annotate files for Synapse project '{project}'")
  
  # test_user will override main recipient when sending out message 
  if(!is.null(test_user)) recipient <- test_user
  # If length of recipient = 1, need to list to become JSON array
  recipients <- if(!is.null(dcc) && dcc != "") as.list(as.character(unique(c(recipient, dcc)))) else list(as.character(recipient))
  if(dry_run) {
    cat("to:", paste(recipients, collapse = " "), "\n",
        "subject:", msg_subj, "\n\n",
        msg_body)
  } else {
    .syn$sendMessage(userIds = recipients,
                     messageSubject = msg_subj, 
                     messageBody = msg_body,
                     contentType = "text/html")
  }
}

# WRAPPER ----------------------------------------------------------------------#

#' Create annotation reminder list by user at the level of files or folders
#' 
#' The return represents a reminder list for a Synapse project. 
#' The list is organized by the user who uploaded the files (many projects have more than one uploader). 
#' In the examples below, `111` and `222` are user ids.
#' 
#' The default provides a list of folders which contain un-annotated files by user, which looks like:
#' `n` = Summary number of offending files for the entire project.
#' `naf` = List of folders with offending files organized by the file creator.
#' Structure:
#' `list(n = 3, naf = list(`111` = c('folder1', 'folder2'), `222` = c('folder2')))`. 
#' 
#' Alternatively, can generate a more granular list of un-annotated files, which looks like:
#' `n` = Summary number of offending files for the entire project.
#' `naf` = List of offending files organized by the file creator. 
#' Structure:
#' `list(n = 3, naf = list(`111` = c('team1_file1.csv', 'team2_file2.csv', ...), `222` = c('team2_file1.txt', ...)))`. 
#' 
#' @param study_files A data.table with file records for a study, aka Synapse project.
#' @param list_type List results by folder or file, default = "folder".
#' @param list_max_len Max length of list to return for each user. Default 10.
make_study_reminder_list <- function(study_files,
                                     list_type = c("folder", "file"),
                                     list_max_len = 10) {
  
  # Provide `n`
  n <- study_files[, .N]
  
  # First nest by creator
  study_files <- split(study_files, by = "createdBy", keep.by = F)
  
  # Values depend on whether folder- or file-level references is desired
  list_type <- match.arg(list_type)
  if(list_type == "folder") {
    naf <- lapply(study_files, function(x) {
      folder_ids <- head(unique(x$parentId), list_max_len) 
      folder_names <- ids_to_names(folder_ids)
      unlist(Map(as_syn_link, folder_names, folder_ids, label = "📁 "))
    })
  } else {
    naf <- lapply(study_files, function(x) {
      file_names <- head(x$name, list_max_len)
      file_ids <- head(x$ids, list_max_len)
      unlist(Map(as_syn_link, file_names, file_ids))
    })
  }
  
  return(list(n = n, naf = naf))
}

#' Query, filter, list for active projects
#' 
make_active_study_reminder_list <- function(study_tab_id, fileview_tab_id) {
  
  studies <- get_active_studies(study_tab_id)
  study_ids <- studies$studyId 
  files <- query_file_attributes(study_ids, fileview_tab_id)$asDataFrame()
  # Add study names
  files$studyName <- studies$studyName[match(files$projectId, studies$studyId)]
  dt <- as.data.table(files)
  dt <- dt %>% 
    filter_by_date() %>%
    filter_by_glob() %>%
    filter_by_type() %>%
    filter_by_user()
  
  by_study <- split(dt, by = "studyName")
  reminder_list_by_study <- lapply(by_study, make_study_reminder_list)
  return(reminder_list_by_study)
}


