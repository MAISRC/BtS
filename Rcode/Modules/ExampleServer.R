#A SERVER MODULE CONSISTS OF A FUNCTION WITH THESE THREE MANDATORY INPUTS. THEN, ALL DESIRED SERVER CONTENTS GO INSIDE THE FUNCTION'S BRACES.

exampleServer = function(input, output, session) {


# ### ESTABLISHING REACTIVE VALUES ### ------------------------------------

#REACTIVE VALUES ARE DYNAMIC OBJECTS THAT CAN KEEP TRACK OF STATES AND INTERMEDIATE OBJECTS WHILE THE APP IS RUNNING. I LIKE TO ESTABLISH ALL OF THESE AT THE TOP OF EACH SERVER MODULE.  

  example_reactives = shiny::reactiveValues(
  )
  
  #THIS IS HOW YOU'D CREATE A WAITER OBJECT FOR COVERING UP SOME UI ELEMENT WHILE OPERATIONS ARE PERFORMED ON IT. TURN IT ON USING ex_waiter$show() AND TURN IT OFF USING $hide()
  ex_waiter = Waiter$new(id = "someUIobject", 
                           html = spin_hexdots(),
                           color = "#ffb71e",
                           hide_on_render = TRUE)
  

# ### ESTABLISH STATIC ELEMENTS ### ---------------------------------------

#SOME UI ELEMENTS ARE RENDERED A SINGLE TIME BY THE APP AND REMAIN STATIC THEREAFTER. I GENERATE THOSE NEAR THE TOP. 
  
  #HERE IS AN EXAMPLE DOWNLOADHANDLER, WHICH IS WHAT EMPOWERED A DOWNLOAD BUTTON IN THE UI. 
  # output$example = downloadHandler("file_name",
  #                                          contentType = "text/csv",
  #                                          content = function(file) { 
  #                                            data = isolate(browse_reactives$curr_browseDT) #Grab current data.
  #                                            data = data %>% #Rework the taxa column to remove all HTML tags (thanks CHATGPT!)
  #                                              mutate(...)
  #                                            write.csv(data, file, row.names = FALSE)
  #                                          })
  
#HERE IS SOME CODE NEEDED TO RENDER A LEAFLET MAP TO SHOW THE COMMON ELEMENTS REQUIRED. 
  
  # output$interactivemap = leaflet::renderLeaflet({
  # 
  #   leaflet::leaflet() %>%
  #     leaflet::addTiles(options = leaflet::providerTileOptions(minZoom = 6, maxZoom = 15)) %>% 
  #     leaflet::addPolygons(data = MN$geometry, 
  #                 color = "black", 
  #                 opacity = 1, 
  #                 fillOpacity = 0, 
  #                 weight = 2, 
  #                 group = "MN_boundary") %>% 
  #     leaflet::addCircleMarkers(data=curr.df$geometry,
  #                               radius = 4.5, 
  #                               group = "circ_marks",
  #                      stroke=T, 
  #                      color = "black",
  #                      weight = 2,
  #                      fillColor = curr.df$colors4markers,
  #                      fillOpacity = 1, 
  #                      label = base::lapply(curr.df$maplabels, HTML), 
  #                      labelOptions = leaflet::labelOptions(
  #                        className = "map_hovers",
  #                      ),
  #                      layerId = curr.df$DOW) 
  # })


# ### MODULE  OBSERVERS ### -----------------------------------------------

#BECAUSE MOST SERVER OPERATIONS ARE PERFORMED IN RESPONSE TO USER ACTIONS, MUCH OF A MODULE'S SERVER CODE WILL BE OBSERVERS (observe(), observeEvent(), eventReactive(), etc.). I PLACE THESE NEXT, OFTEN HAVING SUBHEADINGS FOR EACH IMPORTANT SUBCLASS OF OBSERVER I HAVE (USUALLY BASED ON PURPOSE OR ELEMENT INVOLVED).

#HERE'S AN EXAMPLE THAT LISTENS TO A HOST OF REACTIVE VALUES AND THEN RESPONDS WITH A LEAFLETPROXY TO UPDATE A LEAFLET MAP
  
# observeEvent(listen_select_click(),
#              priority = 0, 
#              ignoreInit = T, {
#  
#     leaflet::leafletProxy("interactivemap") %>% 
#       leaflet::removeMarker(layerId = c(IDs,
#                                     input$interactivemap_marker_click$id))  %>% 
#       leaflet::addCircleMarkers(data=filtered.dat$geometry, 
#                                 radius = 4.5, group = "circ_marks",
#                        stroke=T, color = "black", weight = 2,
#                        fillColor = filtered.dat$colors4markers, fillOpacity = 1, 
#                        label = base::lapply(filtered.dat$maplabels, HTML), 
#                        labelOptions = leaflet::labelOptions(
#                          className = "map_hovers", 
#                        ),
#                        layerId = filtered.dat$DOW)
# 
# })
#   

#HERE IS AN EXAMPLE RENDERDT CALL THAT SHOWS OFF MANY OF THE CUSTOMIZATIONS ONE CAN ACHIEVE WITH THESE. 
#   output$interactivemap.df = DT::renderDT({
#     
#     lakes.summary.definitive %>% 
#         dplyr::filter(FALSE) %>% 
#         base::data.frame() %>% 
#         dplyr::rename("DOW #" = DOW,
#                "Lake" = LAKE_NAME, 
#                "# years surveyed" = nyears,
#                "# surveys" = nsurveys,
#                "Survey dates" = surveylist,
#                "# taxa observed" = ntaxa,
#                "All taxa (invasives in bold)" = taxalist,
#                "County" = cty_name) %>% 
#         dplyr::select(`DOW #`, Lake, County, `# surveys`, 
#                       `Survey dates`, `# taxa observed`, `All taxa (invasives in bold)`) 
#     }, 
#     fillContainer =  TRUE,
#     escape = FALSE,
#     selection = list(mode = "single", target = "row"),
#     caption = tags$caption('Summary of survey data by lake. Click or tap on a lake\'s map marker to activate it and display its summary data here.'),
#     options = base::list(
#       language = list(emptyTable = HTML("<caption style = 'color: #545454; width: max-content;'>No lakes activated yet.</caption>")),
#       columnDefs = base::list(
#         list(visible = FALSE, targets = 0), 
#         base::list(className = 'dt-right', targets = "_all"),
#                         base::list(className = 'dt-top', targets = "_all"),
#                         base::list(width = "200%", targets = 7)), 
#       bordered = TRUE,
#       scrollX = TRUE,
#       paging = T, 
#       searching = T, 
#       ordering = T)
# )

#DT PROXIES WORK A LITTLE DIFFERENTLY THAN THOSE OF LEAFLET. HERE IS A COMMON WORKFLOW, INVOLVING FIRST SETTING UP THE PROXY, THEN REFERENCING IT WITH A SPECIFIC HELPER OPERATION FUNCTION. 
  # DTproxyBrowse = DT::dataTableProxy("interactivemap.df") 
  # 
  # shiny::observeEvent(base::list(browse_reactives$activeIDs,input$commonVsSci), { 
  # 
  #     DT::replaceData(proxy = DTproxyBrowse, data = newBrowseDT)
  # 
  # })

  #HERE'S AN EXAMPLE OF AN OBSERVER CREATING A SHINY MODAL. 
  # shiny::observeEvent(input$lakes_list, {
  #   
  #   shiny::showModal(
  #     shiny::modalDialog(fade = TRUE, 
  #                        size = "m", 
  #                        easyClose = TRUE, 
  #                        title = "Lakes list",
  #                        HTML(base::paste0("<div class = 'infoPopUpsText'>Here is a list of all the lakes with records currently showing in the table: <br><br>", string2show, "</div>"))
  #         
  #     )
  #   )
  # 
  # })

  #HERE'S AN EXAMPLE OBSERVER THAT OPENS/CLOSES AN ACCORDIAN-STYLE MENU CONTROLLED BY A SHINY ACTIONBUTTON. 
  observeEvent(input$toggle_filters, {

    if(checkIfEven(input$toggle_filters)) {

      shinyjs::hide("hidden_filters",
           anim = TRUE,
           animType = "slide")

      updateActionButton(session,
                         "toggle_filters",
                         label = "  Show filters and toggles",
                         icon = icon("plus"))

    } else {

      shinyjs::show("hidden_filters",
           anim = TRUE,
           animType = "slide")

      updateActionButton(session,
                         "toggle_filters",
                         label = "  Hide filters and toggles",
                         icon = icon("minus"))
    }

    toggleAriaExpanded("toggle_filters")
  })
  
}