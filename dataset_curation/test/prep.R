library(nfportalutils)
library(data.table)
syn_login()

query_result <- .syn$tableQuery("select studyId from syn52694652 where dataStatus = 'Available' or dataStatus = 'Partially Available'")$asDataFrame()
ids <- query_result$studyId

datasets <- lapply(ids, function(x) list_project_datasets(x, type = "dataset"))
names(datasets) <- ids
count <- lengths(datasets)

summary <- data.frame(project = ids, datasets = count)
todo <- summary[summary$datasets != 0, ]
models <- LETTERS[1:3]

#' Create experimental design DF
#' 
#' Distribute projects/datasets roughly evenly across experimental conditions (models)
#' using round-robin assignment.
#'
#' @param todo data.frame of projects and datasets to distribute
#' @param models Vector of ids/names of different models to test
#' @param batches Number of evaluation batches
#' @return A data frame with the experimental design allocation
create_design_df <- function(todo, 
                             models = models,
                             batches = 4) {
  
  result <- todo[order(-todo$datasets), ]
  per_batch <- ceiling(nrow(result) / batches)
  result$batch <- rep(1:batches, length.out = nrow(result))
  result$model <- rep(models, length.out = nrow(result))
  as.data.table(result)
}

result <- create_design_df(todo)
result[, sum(datasets), by = batch]
result[, sum(datasets), by = model]
result[, sum(datasets), by = .(batch, model)][order(batch)]
result[, mean(datasets), by = model]


to_split <- datasets[result$project]

for (m in models) {
  jsonlite::write_json(to_split[result[model == m, project]], auto_unbox = T, path = paste0(m, ".json")) 
}

write.csv(result, file = "design.csv", row.names = F)

# Table going into GH docs
knitr::kable(result[order(batch), .(project, datasets, batch)], row.names = T)
