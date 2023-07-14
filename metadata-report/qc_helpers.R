#' Compile all individual fileviews
#' 
#' This pulls indicated fileviews into a single long-format table with:
#' `key`, `value`, `.r`, `.id`, 
#' where `.id` is the fileview that contains that key-value pair.
#' The result can be passed to the check fun `validMeta`.
#' @param fileview_ids IDs of of relevant fileviews
#' @param exclude Annotation keys that will not be included in the compilation.
#' @param verbose Output details along the way.
compileFileviews <- function(fileview_ids, exclude, verbose = TRUE) {
  
  result <- list()
  for(i in fileview_ids) {
    result[[i]] <- try(table_query(i))
    if(verbose) cat("Queried", i)
  }
  failed_pull <- sapply(result, class) == "try-error"
  if(any(failed_pull)) {
    message("Failed to pull, ignoring:", fileview_ids[which(failed_pull)])
  }
  fvs <- result[!failed_pull]
  # If return a fileview with no annotations (no rows), also ignore
  empty <- sapply(fvs, nrow) == 0 
  if(verbose) cat("Empty:", names(fvs)[which(empty)])
  fvs <- fvs[!empty]
  if(!length(fvs)) error("No fileviews to process!")
  fvs <- lapply(fvs, compileFormat, exclude)
  fvs <- rbindlist(fvs, idcol = TRUE) # concatenation
  return(fvs)
}

#' Helper to transform data to long format for straightforward concatenation
#' 
#' This also filters out any annotations not supposed to be in final compilation
compileFormat <- function(dt, exclude) {
  dt <- as.data.table(dt)
  dt <- dt[, !names(dt) %in% exclude, with = FALSE]
  for(col in names(dt)) {
    set(dt, j = col, value = as.character(dt[[col]]))
  }
  if(!length(dt)) {
    message("Ignoring view with no user annotations")
    return(NULL)
  }
  dt <- melt(dt, measure.vars = names(dt), variable.name = "key", na.rm = TRUE)
  # Aside from <NA>, remove rows where value %in% c("", "nan", "NA", "NaN")
  dt <- dt[!value %in% c("", "nan", "NA", "NaN")]
  # Unique key-value pairs 
  dt <- unique(dt)
  # Add some bookkeeping before expanding any list values
  dt[, .r := 1:.N]
  dt <- dt[, .(value = unlist(strsplit(value, split = ", ?"))), by = .(key, .r)]
  dt
}

#' Convert a .csv schema to a keyed lookup
asLookup <- function(schema) {
  lookup <- schema[!duplicated(Attribute), .(key = Attribute, value = strsplit(`Valid Values`, split = ", ?"))]
  lookup[, constrained := lengths(value) > 0] 
  lookup <- lookup[, .(value = unlist(value), valid = TRUE), by = .(key, constrained)] 
  setkey(lookup, key, value) # keys with length-0 valid values have <NA> value
  return(lookup)
}

#' Check whether valid keys and values
#' 
#' Note that `.key` and `.value` should be vectors to take advantage of `data.table`'s lookup.
#' This annotates data with `validkey` and `valid` and according to the schema:
#' `validkey` indicates whether the concept exists in schema;
#' `valid` is more combinatorial and indicates whether value is valid, dependent on `validkey`.
#' If an annotation key is not in the schema, then `valid` is <NA>,
#' e.g. if historically someone annotated a data file using key-value pair
#' "RandomAnnotation" = "meh", 
#' and "RandomAnnotation" exists outside our definitions, 
#' we don't pass judgement on whether "meh" is valid.
validMeta <- function(.key, .value, lookup) {
  # valid indicates if key-value combination is valid, i.e. present in lookup
  result <- lookup[.(.key, .value), .(key, value, valid)]
  # key can be valid without key-value combo being valid
  result[, validkey := .key %in% lookup$key]
  # for valid = NA, truly NA for unconstrained free-text fields, otherwise not valid
  result[is.na(valid), valid := fifelse(lookup$constrained[match(key, lookup$key)], FALSE, NA)]
  return(result)
}

#' Helper to subset to only problematic keys/values
report_data_subset <- function(report_data) {
  report_data[validkey == FALSE | sapply(valid, function(x) any(x == FALSE))]
}

#' Render pretty HTML report table
#' 
#' @param records The table.
#' @param limit Max unique values by key shown (mostly matters for free-text fields).
reportTable <- function(dt, limit = 20) {
  dt <- dt[, head(.SD, limit), by = key]
  dt[, .id := sapply(.id, toString)]
  reactable(
    dt,
    groupBy = c("key"),
    filterable = TRUE,
    columns = list(
      key = colDef(), # aggregate = "count"
      value = colDef(cell = function(value, index) {
        css <- dt[index, valueCSS][[1]]
        Map(function(value, css) span(class = css, value), value, css)
      }),
      valid = colDef(maxWidth = 50),
      validkey = colDef(aggregate = "unique",
                        maxWidth = 50),
      valueCSS = colDef(show = FALSE),
      .r = colDef(show = FALSE)
    ),
    bordered = TRUE
  )
}

