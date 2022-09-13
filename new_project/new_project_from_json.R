#!/usr/bin/env Rscript

config <- commandArgs(trailingOnly = TRUE)

library(nfportalutils)
syn_login()

config <- jsonlite::read_json(config)

NAME <- config$name
PI <- config$PI
LEAD <- config$dataLead
# Combined field for study table
LEADS <- paste(unique(c(PI, LEAD), sep = ",")) 
SUMMARY <- config$summary
FUNDER <- config$fundingAgency
INITIATIVE <- config$initiative
INSTITUTION <- paste(config$institution, sep = ";")
FOCUS <-  paste(config$diseaseFocus, sep = ",")
MANIFESTATIONS <- paste(config$diseaseManifestations, sep = ",")
GRANT_DOI <- paste(config$grantDOI, sep = ",")

# Create
created_project <- new_project(name = NAME,
                               pi = PI,
                               lead = LEAD,
                               abstract = SUMMARY,
                               institution = INSTITUTION,
                               funder = FUNDER,
                               initiative = INITIATIVE)

PROJECT_ID <- created_project$properties$id
FILEVIEW_ID <- attr(created_project, "fileview")

# Register
STUDY_TABLE_ID <- if(Sys.getenv("PROFILE") == "TEST") "syn27353709" else "syn16787123"
nfportalutils::register_study(name = NAME,
                              project_id = PROJECT_ID,
                              abstract = SUMMARY, 
                              lead = LEADS,
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

# Output variables
cat("SYNAPSE_PROJECT_ID=",PROJECT_ID, "\n",
    "SYNAPSE_FILEVIEW_ID=",FILEVIEW_ID, 
    file = "new_project.log", sep = "") 
