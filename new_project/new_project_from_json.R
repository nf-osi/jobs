#!/usr/bin/env Rscript

configs <- commandArgs(trailingOnly = TRUE)

library(nfportalutils)
syn_login()


register_check <- Sys.getenv("PROFILE") == "TEST"
# Note that dataset folders must have unique names (Synapse won't create duplicates)
# Since this can't be enforced at the JSON schema level, we adjust folder names using `make.unique` as necessary
#' @param register_study Depends on whether PROFILE=TEST. 
setup_from_config <- function(config_file, skip_register = register_check) {
  
  config <- jsonlite::read_json(config_file)
  
  NAME <- config$name
  
  # People
  PI <- unlist(config$PI)
  PI_CSV <- paste(PI, collapse = ", ")
  LEAD <- unlist(config$dataLead)
  LEAD_CSV <- paste(unique(c(PI, LEAD)), collapse = ", ")
  ADMIN <- config$synPrincipal
  
  
  # Other meta
  SUMMARY <- config$summary
  FUNDER <- config$fundingAgency
  INITIATIVE <- config$initiative
  INSTITUTION <- paste(unlist(config$institution), collapse = "; ")
  FOCUS <-  paste(unlist(config$diseaseFocus), collapse = ",")
  MANIFESTATIONS <- paste(unlist(config$diseaseManifestations), collapse = ", ")
  GRANT_DOI <- paste(config$grantDOI, collapse = ", ")
  
  # Other governance
  INITPUBLICVIEW <- config$governance$initPublicView
  INITPUBLICVIEW <- if(!is.null(INITPUBLICVIEW) && is.logical(INITPUBLICVIEW)) INITPUBLICVIEW else FALSE
  ADMIN <- config$synPrincipal
  
  # Data
  DATA_DEPOSIT <- config$dataDeposit
  DATASETS <- NULL
  if(!is.null(DATA_DEPOSIT) && length(DATA_DEPOSIT[[1]])) {
    DATASETS <- sapply(DATA_DEPOSIT, function(x) x$dataLabel)
    DATASETS <- make.unique(DATASETS, sep = " ")
    DATASETS <- as.list(DATASETS)
    for(i in seq_along(DATA_DEPOSIT)) {
      # Set selected attributes -- note that properties not present resolve to NULL, which is OK 
      attr(DATASETS[[i]], "assay") <- DATA_DEPOSIT[[i]]$dataAssay
      attr(DATASETS[[i]], "dataType") <- DATA_DEPOSIT[[i]]$dataType
      attr(DATASETS[[i]], "description") <- DATA_DEPOSIT[[i]]$dataDescription
      attr(DATASETS[[i]], "progressReportNumber") <- DATA_DEPOSIT[[i]]$dataProgressReportNumber
      attr(DATASETS[[i]], "contentType") <- "dataset"
    }
  }
  
  # Non-data -- see schema for allowed resources
  OTHER_RESOURCES <- NULL
  if(length(config$nonDataResources)) {
    resources <- unique(sapply(config$nonDataResources, `[[`, "resourceType"))
    cat("Non-data resources:", resources, "\n")
    if(length(resources)) {
      if(grep("protocol", resources)) OTHER_RESOURCES <- append(OTHER_RESOURCES, "Protocols")
      if(grep("tool", resources)) OTHER_RESOURCES <- append(OTHER_RESOURCES, "Tools")
    }
  }
  
  # Create
  created_project <- new_project(name = NAME,
                                 pi = PI_CSV,
                                 lead = LEAD_CSV,
                                 admin_user = ADMIN,
                                 abstract = SUMMARY,
                                 institution = INSTITUTION,
                                 funder = FUNDER,
                                 initiative = INITIATIVE,
                                 publicview = INITPUBLICVIEW,
                                 datasets = DATASETS,
                                 other_resources = OTHER_RESOURCES
                                 )
  
  PROJECT_ID <- created_project$properties$id
  FILEVIEW_ID <- attr(created_project, "fileview")
  
  # Write new syn id to config 
  cat("Writing", PROJECT_ID, "to", config_file, "\n")
  command <- paste0('jq \'. += { "studyId" : "',  PROJECT_ID, '" }\' ', config_file, ' > tmp.json && mv tmp.json ' , config_file)
  system(command)
  
  # Register with some translations
  config$studyLeads <- config$PI
  config$studyFileviewId <- FILEVIEW_ID
  config$studyName <- config$name
  config$institutions <- config$institution
  config$manifestation <- config$diseaseManifestation
  
  if(skip_register) cat("Study not registered since profile detected is TEST", "\n")
  if(!skip_register) nfportalutils::register_study(id = PROJECT_ID,
                                study_meta = config,
                                summary = SUMMARY,
                                study_summary_table = "syn16787123",
                                portal_project_view = "syn52677631")
  
  # Add to scope of master portal fileview
  if(!skip_register) nfportalutils::register_study_files(PROJECT_ID)
  
}

for(config in configs) {
  cat("--- Preparing using", config, "---\n")
  try({
    setup_from_config(config)
  })
}
