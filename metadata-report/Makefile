# Compile and render a report for metadata (annotations) across projects
AUTHTOKEN = ${SYNAPSE_AUTH_TOKEN}

# Recompile the data before rendering
updated_report:
	  Rscript -e "rmarkdown::render('build_report.Rmd', output_file='index.html',params=list(update = TRUE, authtoken = '${AUTHTOKEN}'))"

# Render report with saved data
report:
	  Rscript -e "rmarkdown::render('build_report.Rmd', output_file='index.html')"

# (TO DO) diff generates a diff using the current version vs last commit in git history;
# This facilitates tracking what has been corrected
diff:
	  @echo "Not yet implemented"
