function(input, output, session) {
  parquetFile = 'wego-clean.parquet'
  
  con <- dbConnect(duckdb::duckdb(), ":memory:")
  
  dbExecute(con, paste0("CREATE OR REPLACE VIEW operator_data AS SELECT * FROM parquet_scan('", parquetFile, "')"))
  
  operatorData <- reactive({
    req(input$operatorInput)
    countQuery <- sprintf("SELECT OPERATOR, COUNT(UNIQUE_TRIP_ID) as unique_trips
                            FROM operator_data 
                            WHERE OPERATOR IN (%s) 
                            GROUP BY OPERATOR", 
                            paste0("'", input$operatorInput, "'", collapse = ", "))
    countData <- dbGetQuery(con, countQuery)

    valueQuery <- sprintf("SELECT OPERATOR, HDWY_DEV, ADHERENCE 
                               FROM operator_data 
                               WHERE OPERATOR IN (%s)", 
                               paste0("'", input$operatorInput, "'", collapse = ", "))
        valueData <- dbGetQuery(con, valueQuery)

        list(countData = countData, valueData = valueData)
  })

output$dynamicH2 <- renderUI({
        # Fetch the number of trips (replace this with your actual logic)
        data <- operatorData()
        numTrips <- data$countData$unique_trips # Example value

        tagList(
            h2(paste("Number of Unique Trips:", numTrips)),
            fluidRow(
                column(6, plotOutput("hdwyDevPlot")),
                column(6, plotOutput("adherencePlot"))
            )
        )
    })

output$hdwyDevPlot <- renderPlot({
        data <- operatorData()$valueData
        ggplot(data, aes(x = factor(OPERATOR), y = HDWY_DEV)) +
            geom_boxplot(             # custom boxes
                color="blue",
                fill="blue",
                alpha=0.2,
                
                # Notch?
                notch=TRUE,
                notchwidth = 0.8,
                
                # custom outliers
                outlier.colour="red",
                outlier.fill="red",
                outlier.size=3
            ) +
            theme_minimal() +
            xlab("Operator") +
            ylab("Headway Deviation")
    })

    # Reactive plot for Mean Adherence
    output$adherencePlot <- renderPlot({
        data <- operatorData()$valueData
        ggplot(data, aes(x = factor(OPERATOR), y = ADHERENCE)) +
            geom_boxplot(
                color="blue",
                fill="blue",
                alpha=0.2,
                
                # Notch?
                notch=TRUE,
                notchwidth = 0.8,
                
                # custom outliers
                outlier.colour="red",
                outlier.fill="red",
                outlier.size=3
            ) +
            theme_minimal() +
            xlab("Operator") +
            ylab("Adherence")
    })


    session$onSessionEnded(function() {
    dbDisconnect(con)
  })
}