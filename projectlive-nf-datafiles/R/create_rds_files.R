require(magrittr)

incoming_data_table <- "syn51471723" # used to be syn23364404
live_folder <- "syn22281727"
dev_folder  <- "syn24474593"

# Define job
schedule <- if(Sys.getenv("SCHEDULE") != "") paste(Sys.getenv("SCHEDULE"), "-") else ""
job <- list(
  main = paste(schedule, "create_projectlive_rds"))

try(withCallingHandlers({

  source("https://raw.githubusercontent.com/Sage-Bionetworks/projectlive.modules/231f14aa9a4c35a4cad46c851ff05eb07dff3f19/R/synapse_functions.R")
  source("https://raw.githubusercontent.com/Sage-Bionetworks/projectlive.modules/231f14aa9a4c35a4cad46c851ff05eb07dff3f19/R/data_manipulation_functions.R")
  source("https://raw.githubusercontent.com/nf-osi/jobs/764c62a94be9fd4dc2b0e04dd310c07472044faa/utils/slack.R")

  reticulate::use_condaenv("sage-bionetworks", required = T)
  synapseclient <- reticulate::import("synapseclient")
  syn <- synapseclient$Synapse()
  auth_token <- rjson::fromJSON(Sys.getenv("SCHEDULED_JOB_SECRETS"))$SYNAPSE_AUTH_TOKEN
  syn$login(authToken=auth_token)

  store_file_in_synapse <- function(syn, file, parent_id){
    file <- reticulate::import("synapseclient")$File(file, parent_id)
    syn$store(file)
  }



  # studies ----
  studies <- get_synapse_tbl(syn, "syn52694652")
  saveRDS(studies, "studies.RDS")

  store_file_in_synapse(
    syn,
    "studies.RDS",
    dev_folder
  )

  store_file_in_synapse(
    syn,
    "studies.RDS",
    live_folder
  )

  file.remove("studies.RDS")


  # files ----
  dev_files <-
    get_synapse_tbl(
      syn,
      "syn16858331",
      columns = c(
        "id",
        "name",
        "individualID",
        "parentId",
        "specimenID",
        "assay",
        "initiative",
        "dataType",
        "fileFormat",
        "resourceType",
        "accessType",
        "tumorType",
        "species",
        "projectId",
        "benefactorId",
        "consortium",
        "progressReportNumber",
        "createdOn",
        "type"
      ),
      col_types = readr::cols(
        "consortium" = readr::col_character(),
        "progressReportNumber" = readr::col_integer()
      )
    ) %>%
    dplyr::rename("studyId" = "projectId") %>%
    dplyr::filter(type == "file") %>%
    format_date_columns() %>%
    dplyr::select(-c("createdOn")) %>%
    dplyr::inner_join(
      dplyr::select(
        studies,
        "studyName",
        "studyLeads",
        "fundingAgency",
        "studyId"
      ),
      by = "studyId"
    ) %>%
    dplyr::mutate("reportMilestone" = .data$progressReportNumber)

  saveRDS(dev_files, "files.RDS")
  store_file_in_synapse(syn, "files.RDS", dev_folder)
  file.remove("files.RDS")

  live_files <- dev_files

  saveRDS(live_files, "files.RDS")
  store_file_in_synapse(syn, "files.RDS", live_folder)
  file.remove("files.RDS")


  # incoming data ----
  dev_incoming_data <-
    get_synapse_tbl(
      syn,
      incoming_data_table,
      columns = c(
        "fileFormat",
        "date_uploadestimate",
        "progressReportNumber",
        "estimatedMinNumSamples",
        "fundingAgency",
        "studyId",
        "dataType"
      ),
      col_types = readr::cols(
        "estimatedMinNumSamples" = readr::col_integer(),
        "progressReportNumber" = readr::col_integer()
      )
    ) %>%
    dplyr::left_join(
      dplyr::select(studies, "studyName", "studyId"),
      by = c("studyId" = "studyId")
    ) %>%
    dplyr::mutate(
      "date_uploadestimate" = lubridate::mdy(date_uploadestimate),
    ) %>%
    dplyr::filter(
      !is.na(.data$date_uploadestimate) | !is.na(.data$progressReportNumber)
    ) %>%
    tidyr::unnest("fileFormat") %>%
    dplyr::group_by(
      .data$fileFormat,
      .data$date_uploadestimate,
      .data$progressReportNumber,
      .data$fundingAgency,
      .data$studyName,
      .data$dataType,
      .data$studyId
    ) %>%
    dplyr::summarise("estimatedMinNumSamples" = sum(.data$estimatedMinNumSamples)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      "estimatedMinNumSamples" = dplyr::if_else(
        is.na(.data$estimatedMinNumSamples),
        0L,
        .data$estimatedMinNumSamples
      ),
      "reportMilestone" = .data$progressReportNumber
    )

  saveRDS(dev_incoming_data, "incoming_data.RDS")
  store_file_in_synapse(syn, "incoming_data.RDS", dev_folder)
  file.remove("incoming_data.RDS")

  live_incoming_data <- dev_incoming_data


  saveRDS(live_incoming_data, "incoming_data.RDS")
  store_file_in_synapse(syn, "incoming_data.RDS", live_folder)
  file.remove("incoming_data.RDS")


  # publications ----
  pubs <-
    get_synapse_tbl(syn, "syn16857542") %>%
    dplyr::mutate(
      "year" = forcats::as_factor(.data$year),
      "year" = forcats::fct_expand(.data$year, "2015"),
      "year" = forcats::fct_relevel(.data$year, sort)
    )
  saveRDS(pubs, "pubs.RDS")
  store_file_in_synapse(syn, "pubs.RDS", live_folder)
  store_file_in_synapse(syn, "pubs.RDS", dev_folder)
  file.remove("pubs.RDS")

  # tools ----
  tools <- get_synapse_tbl(syn, "syn16859448")
  saveRDS(tools, "tools.RDS")
  store_file_in_synapse(syn, "tools.RDS", live_folder)
  store_file_in_synapse(syn, "tools.RDS", dev_folder)
  file.remove("tools.RDS")

  },
  error = function(e) handleError(e, "main"))
)

slack_report(report)

