library(shiny)
library(DBI)
library(duckdb)
library(ggplot2)
library(aws.s3)

con <- dbConnect(duckdb::duckdb(), ":memory:")
dbExecute(con, "CREATE VIEW operators_view AS SELECT DISTINCT OPERATOR FROM parquet_scan('wego-clean.parquet') GROUP BY OPERATOR HAVING COUNT(UNIQUE_TRIP_ID) > 400")
choices_df <- dbGetQuery(con, "SELECT * FROM operators_view ")
dbDisconnect(con)

# Convert the extracted choices to a list format required by checkboxGroupInput
choices_list <- setNames(choices_df[[1]], choices_df[[1]])