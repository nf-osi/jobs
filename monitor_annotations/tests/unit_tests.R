source("../helpers.R")

mock_reminder_list <- list(
  syn123 = list(`naf` = list(`3423450` = c("folderA", "folderB"), `3421893` = "folderC")),
  syn456 = list(`naf` = list(`3434950` = c("folderA")))
)

mock_no_email_list <- c("3421893")
  
testthat::test_that("Confirms that 3421893 is skipped", {
  
  testthat::expect_message(send_message_list(todo = mock_reminder_list, 
                                             no_email_list_users = mock_no_email_list, 
                                             dry_run = TRUE,
                                             sleep_interval = 0),
                           "Skipping reminder for: 3421893")
  }
)
