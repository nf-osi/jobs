reticulate::use_virtualenv("/r-reticulate")

library(nfportalutils)
library(jsonlite)
library(httr)

# Values -----------------------------------------------------------------------#
# Extract and use token
secrets <- jsonlite::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))
token <- secrets[["SYNAPSE_AUTH_TOKEN"]]
syn_login(authtoken = token)

# Input/target tables
study_tab_id <- 'syn52694652'
portal_fileview_id <- 'syn16858331'

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(main = paste(schedule, "update_study_annotations"))


# Main -------------------------------------------------------------------------#

source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")


#' Query with some handling for very long lists
benefactor_query <- function(ids, portal_fileview) {

  id_lists <- split(ids, ceiling(seq_along(ids)/1000))
  ben_results <- c()
  for(i in names(id_lists)) {
    batch <- paste(sQuote(id_lists[[i]], q = FALSE), collapse = ",")
    meta <- .syn$tableQuery(glue::glue("select distinct benefactorId from {portal_fileview} where id in ({batch})"))  
    bens <- unlist(meta$asDataFrame())
    ben_results <- append(ben_results, bens)
  }
  ben_results <- unique(ben_results)
  paste(ben_results, sep = ", ")
}


handleUpdateError <- function(e, subjob, portal_fileview = portal_fileview_id) {

  if(grepl("Not all of the entities were updated.", e)) {
    # parse potentially long error string to get ids and failureCodes
    # error must be accessed as below because of how errors are passed from Python to R
    e_log <- capture.output(print(e))
    json_pattern <- "Failed updates: (\\[.*\\])"
    json_match <- regmatches(e_log, regexpr(json_pattern, e_log, perl = TRUE))
    json_string <- gsub("'", '"', gsub("Failed updates: ", "", json_match))
    failed_records <- fromJSON(json_string)
    reason <- unique(failed_records$failureCode)
    if(length(reason) == 1L && reason == "UNAUTHORIZED") {
      needs_review <- benefactor_query(failed_records$entityId, portal_fileview)
      report[[subjob]] <<- paste0(":warning: ", job[[subjob]], "- Files successfully updated except for those unauthorized. Check\n",
                                  blockquote(needs_review))
    } else {
      report[[subjob]] <<- paste(":x:", job[[subjob]], "failed for some entities for unknown/multiple reasons!")
    }
  } else {
    report[[subjob]] <<- paste(":x:", job[[subjob]], "failed!")
  }
  # traceback()
}

try({
    withCallingHandlers(
    {
      update_study_annotations(study_table_id = study_tab_id,
                               fileview_id = portal_fileview_id,
                               annotations = c("studyId","studyName","fundingAgency","initiative"),
                               dry_run = FALSE)
    }, 
    message = function(m) handleMessage(m, "main"),
    error = function(e) handleUpdateError(e, "main") 
   )
})


slack_report(report)


