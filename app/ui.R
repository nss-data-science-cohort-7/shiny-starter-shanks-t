fluidPage(
  titlePanel("Dropdown with Checkboxes"),

  # Dropdown with checkboxes
  selectInput(
    inputId = "operatorInput", 
    label = "Operator", 
    choices = choices_list,
    # multiple = TRUE, 
    selected = "Operator 1"
  ),

  uiOutput("dynamicH2")
)