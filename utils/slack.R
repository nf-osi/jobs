# Slack module
# Functionality to forward job script status outputs to a Slack channel 

# Create a `report` entity with default success result
# Jobs may have subjobs, but usually this is a single-element list with name "main"
# The default result is modified by the handlers if errors, etc. are thrown during run  
report <- lapply(job, function(x) paste(":white_check_mark:", x))

# Slack msg build --------------------------------------------------------------#

# Optional functionality to send slack report
# Report, created above, becomes a list of messages batched into a single payload
slack_report <- function(report) {
  if(Sys.getenv("SLACK") != "") {
    slack_hook <- Sys.getenv("SLACK")
    
    blocks <- lapply(report, function(text) {
      list(type = "section", 
           text = list(
             type = "mrkdwn",
             text = text
           )
      )
    }
    )
    blocks <- unname(blocks) # for correct payload structure
    payload <- list(blocks = blocks)
    payload <- jsonlite::toJSON(payload, auto_unbox = TRUE)
    print(payload)
    post_status <- httr::POST(url = slack_hook, body = payload, httr::content_type_json())
    cat(post_status$status_code)
  } 
}

blockquote <- function(txt) sprintf(">%s", txt) 

# Handlers --------------------------------------------------------------------#
# The final error or message output will replace default report status 
handleError <- function(e, subjob) {
  report[[subjob]] <<- paste(":x:", job[[subjob]], "failed!")
  traceback()
}

handleMessage <- function(m, subjob) {
  report[[subjob]] <<- paste0(":white_check_mark: ", job[[subjob]], " - with note\n", blockquote(m$message))
}

handleWarning <- function(w, subjob) {
  report[[subjob]] <<- paste0(":warning: ", job[[subjob]], " - with warning\n", blockquote(w$message))
}