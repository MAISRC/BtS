#THE MAIN SERVER FILE IS USUALLY PRETTY SPARSE BECAUSE MUCH OF THE SERVER CODE WILL PROBABLY BE IN MODULE FILES. WHAT EXISTS HERE IS GENERALLY WHAT IS NEEDED TO NAVIGATE BETWEEN TABS/MODULES. 

shinyServer(function(input, output, session) {

# ### NON-MODULARIZED SERVER CODE ### -------------------------------------

  output$sampleText = renderText({
    "Make some content!"
  })

# ### LOAD MODULES ### ----------------------------------------------------

# exampleServer(input, output, session) 
  
# ### OBSERVERS ### ---------------------------------------------------------------
 #A BIG PART OF SHINY SERVER FILES IS OBSERVERS, WHICH WATCH FOR EVENTS AND THEN RESPOND.
  
  # #HERE'S A USEFUL PATTERN--INSIDE AN OBSERVER, STASH VALUES LIKE A USER'S NAME AND EMAIL ADDRESS INTO LOCAL STORAGE:
  # runjs("localStorage.setItem('HighlySpecificName', $('#name').val());") #AFTER THE # PUT THE CORRESPONDING INPUTID
  # runjs("localStorage.setItem('HighlySpecificEmail', $('#email').val());")
  
  # #THEN, HAVE OBSERVERS WATCHING FOR EVENTS CORRESPONDING TO THE APP BOOTING UP THAT GRABS THOSE VALUES FROM STORAGE IF IT FINDS THEM AND PLUGS THEM INTO YOUR INPUTS--IT'S LIKE ALLOWING USERS TO SAVE THEIR PREVIOUS ANSWERS.
  # observeEvent(input$stored_name, {
  #   req(isTruthy(input$stored_name))
  #   updateTextInput(session, "name", value = input$stored_name)
  # })
  # 
  # observeEvent(input$stored_email, {
  #   req(isTruthy(input$stored_email))
  #   updateTextInput(session, "email", value = input$stored_email)
  # })
  
  #THEN, IN THE UI, ADD THIS: IT TRIGGERS ON LAUNCH/REFRESH AND LOOKS FOR YOUR STORED VALUES, TRIGGERING A SHINY EVENT SO THAT THE OBSERVERS ABOVE RUN.
#   tags$head(
#     tags$script(HTML("
#   $(document).on('shiny:connected', function() {
#     var name = localStorage.getItem('HighlySpecificName');
#     var email = localStorage.getItem('HighlySpecificEmail');
#     if(name) Shiny.setInputValue('stored_name', name, {priority: 'event'});
#     if(email) Shiny.setInputValue('stored_email', email, {priority: 'event'});
#   });
# "))
#   ),
  

}) #End Server Side
