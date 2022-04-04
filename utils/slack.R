# Slack module

# Store job results to transmit, which can be modified by handlers 
report <- lapply(job, function(x) paste(":white_check_mark:", x))

# Slack funs ------------------------------------------------------------------#

# Optional functionality to send slack report
# report = a list of messages that will be batched into a single payload
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

# The final error or message output will replace default report status 
handleError <- function(e, subjob) {
  report[[subjob]] <<- paste(":x:", job[[subjob]], "failed!")
  traceback()
}

handleMessage <- function(m, subjob) {
  report[[subjob]] <<- paste0(":white_check_mark: ", job[[subjob]], " - with note\n", blockquote(m$message))
}