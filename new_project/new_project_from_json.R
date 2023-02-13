#!/usr/bin/env Rscript

configs <- commandArgs(trailingOnly = TRUE)

library(nfportalutils)
syn_login()

setup_from_config <- function(config_file) {
  
  config <- jsonlite::read_json(config_file)
  
  NAME <- config$name
  PI <- unlist(config$PI)
  PI_CSV <- paste(PI, collapse = ", ")
  LEAD <- unlist(config$dataLead)
  # Combined field for study table
  LEAD_CSV <- paste(unique(c(PI, LEAD)), collapse = ", ")
  SUMMARY <- config$summary
  FUNDER <- config$fundingAgency
  INITIATIVE <- config$initiative
  INSTITUTION <- paste(unlist(config$institution), collapse = "; ")
  FOCUS <-  paste(unlist(config$diseaseFocus), collapse = ",")
  MANIFESTATIONS <- paste(unlist(config$diseaseManifestations), collapse = ", ")
  GRANT_DOI <- paste(config$grantDOI, collapse = ", ")
  DATASETS <- config$dataDeposit
  if(!is.null(DATASETS)) {
    DATASETS <- sapply(DATASETS, function(x) paste(x$dataLabel, "(", x$dataAssay,")")) 
  }
  
  # Create
  created_project <- new_project(name = NAME,
                                 pi = PI_CSV,
                                 lead = LEAD_CSV,
                                 abstract = SUMMARY,
                                 institution = INSTITUTION,
                                 funder = FUNDER,
                                 initiative = INITIATIVE,
                                 datasets = DATASETS)
  
  PROJECT_ID <- created_project$properties$id
  FILEVIEW_ID <- attr(created_project, "fileview")
  
  # Register
  STUDY_TABLE_ID <- if(Sys.getenv("PROFILE") == "TEST") "syn27353709" else "syn16787123"
  nfportalutils::register_study(name = NAME,
                                project_id = PROJECT_ID,
                                abstract = SUMMARY, 
                                lead =  LEAD_CSV,
                                institution = INSTITUTION, 
                                focus = FOCUS, 
                                manifestation = MANIFESTATIONS,
                                fileview_id = FILEVIEW_ID,
                                funder = FUNDER,
                                initiative = INITIATIVE,
                                grant_doi = GRANT_DOI,
                                study_table_id = STUDY_TABLE_ID)
  
  # Add to scope of master portal fileview
  nfportalutils::register_study_files(PROJECT_ID)
  
  # Write new syn id to config 
  cat("Writing", PROJECT_ID, "to", config_file, "\n")
  command <- paste0('jq \'. += { "studyId" : "',  PROJECT_ID, '" }\' ', config_file, ' > tmp.json && mv tmp.json ' , config_file)
  system(command)
}

for(config in configs) {
  cat("--- Preparing using", config, "---\n")
  try({
    setup_from_config(config)
  })
}
