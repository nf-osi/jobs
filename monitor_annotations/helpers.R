# Helpers for `monitor_annotations.R`

#' Parse non-annotated files
#' 
#' Given fileview query result, generate a list for non-annotated files, with elements:
#' `n` = Number of non-annotated files and 
#' `na_files` = List of non-annotated filenames organized by the file creator, e.g. 
#' `list(n = 3, na_files = list(`111` = c('team1_file1.csv', 'team2_file2.csv'), `222` = c('team2_file1.txt')))`. 
#' Many projects have more than one uploader, and it would be more understandable
#' to send individual, precise emails referencing only the relevant files for that user.
#' @param dt Table query result with `name`, `createdBy`, `resourceType`, `assay`.
#' @param ignore_file File pattern to ignore.
#' @param ignore_type Known types to ignore.
#' @param ignore_user List of user ids to ignore. Defaults to NF service accounts. 
#' @param list_len Max length of list of files to return for each user. Default 50
process_na <- function(dt,
                      ignore_file = "^DSP|data sharing plan|synapse_storage_manifest|.*report|\\.pdf$|\\.docx?$|\\.pptx?$|_annotation\\.csv|md5$",
                      ignore_type = c("curatedData", "result", "tool", "report", "metadata", "protocol", "workflow report"),
                      ignore_user = c(DCC_USER),
                      list_len = 50
) {
  
  dt <- as.data.table(dt$asDataFrame())
  if(nrow(dt) == 0) return(list(n = 0, na_files = NULL)) 
  # ignore using both resourceType AND name pattern matching
  dt <- dt[!grepl(ignore_file, name, ignore.case = TRUE)][!resourceType %in% ignore_type][!createdBy %in% ignore_user]
  dt <- dt[is.na(assay)]
  n <- dt[, .N]
  # Assemble list of creator ~ files for clear list of na_files
  na_files <- split(dt, by = "createdBy", keep.by = F)
  na_files <- lapply(na_files, function(x) paste0(head(x$name, list_len), " (", head(x$id, list_len), ")"))
  return(list(n = n, na_files = na_files))
}


#' Email reminder regarding annotation
#' @param user One or more synapse user ids
#' @param files A representative list of files assigned to the user to include in message.
#' @param project Optional project name or id for context (goes into message subject).
#' @param dcc The DCC Synapse profile id (numeric) to cc on the message. Use FALSE to not copy the DCC.  
#' @param dry_run If TRUE, output message instead of emailing. 
email_re_annotation <- function(recipient,
                              files,
                              project = NULL, 
                              dcc = FALSE,
                              dry_run = TRUE
) {
  
  msg_template <- 
    "Dear NF Data Portal contributor,
  
  Our system shows you have uploaded files which are presently unannotated (some files appended below for reference). 
  NF-OSI encourages (and many NF funders mandate) that data files be annotated so that they and future data users can understand the data.
  Please follow the annotation instructions here: https://help.nf.synapse.org/NFdocs/how-to-annotate-data.
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
  
  # If length of recipient = 1, need to use list to become JSON array
  recipients <- if(dcc) as.list(as.character(unique(c(recipient, dcc)))) else list(as.character(recipient))
  if(dry_run) {
    cat("to:", paste(recipients, collapse = " "), "\n",
        "subject:", msg_subj, "\n\n",
        msg_body)
  } else {
    .syn$sendMessage(userIds = recipients,
                     messageSubject = msg_subj, 
                     messageBody = msg_body,
                     contentType = "text/plain")
  }
}

#' Crawl active study fileviews
#' 
#' TODO: As number of fileviews increase, this should be parallelized
#' @param study_tab_id Study table id.
#' @param verbose Whether to output progress messages.
crawl_active_fileviews <- function(study_tab_id, verbose = TRUE) {
  studies <- .syn$tableQuery(glue::glue("SELECT studyId,studyName,studyFileviewId from {study_tab_id} WHERE studyStatus='Active'"))
  studies <- studies$asDataFrame()
  all_fileviews <- studies$studyFileviewId
  if(verbose) {
    time_est <- round((length(all_fileviews) * 3.15) / 60, 1) # heuristics
    cat("Estimated time to query", length(all_fileviews), "active studies:", time_est, "minutes\n")
  }
  files <- list()
  for(fileview in all_fileviews) {
    if(verbose) cat("Querying fileview", fileview, "\n")
    # Issues to handle:
    # 1) Fileviews can break and be unquery-able, the most common error something like: 
    # 'attribute X size is too small, needs to be __'
    # 2) Columns in query for may be missing for some reason
    files[[fileview]] <- try(
      .syn$tableQuery(
        glue::glue("SELECT id,name,resourceType,assay,createdBy from {fileview} WHERE type='file'")
      )
    )
  }
  
  # Use studyName instead of studyFileviewId as names
  names(files) <- studies$studyName
  
  fail <- names(which(sapply(files, class) == "try-error"))
  if(length(fail)) {
    files <- files[!names(files) %in% fail]
    warning("Successful except for ", length(fail),  " projects with bad fileviews: ", paste(fail, collapse = ", "), call. = FALSE)
  }
  return(files)
}

#' Wrapper to run list of fileview results through `process_na`
filter_na <- function(fileviews, verbose = TRUE) {
  todo <- lapply(fileviews, process_na)
  todo <- Filter(function(x) x$n > 0, todo)
  if(verbose) cat("Number of projects with non-annotated files found:", length(todo), "\n")
  return(todo)
}

