#THE MAIN SERVER FILE IS USUALLY PRETTY SPARSE BECAUSE MUCH OF THE SERVER CODE WILL PROBABLY BE IN MODULE FILES. WHAT EXISTS HERE IS GENERALLY WHAT IS NEEDED TO NAVIGATE BETWEEN TABS/MODULES. 

shinyServer(function(input, output, session) {
  
# ### REACTIVE VALS ### -------------------------------------
  
  curr_map_sf = reactiveVal(IWL_allSources)

# ### NON-MODULARIZED SERVER CODE ### -------------------------------------

  output$infest_map = renderLeaflet({
    
    IWL_start = isolate(curr_map_sf())
    
    IWL_start$lat = st_coordinates(IWL_start)[,2]
    IWL_start$lng = st_coordinates(IWL_start)[,1]
    
    IWF_summs = IWL_start %>% 
      st_drop_geometry() %>% 
      group_by(lat, lng, species) %>% #TO ACCOUNT FOR THE POSSIBILITY THAT TWO DIFFERENT SOURCES HAVE THE SAME TAXON BUT FOR DIFF YEARS, COLLAPSE TO THE EARLIER ONE ACCORDING TO ALL SOURCES AVAILABLE. 
      filter(confirmed_year_inc == min(confirmed_year_inc)) %>% 
      ungroup() %>% 
      group_by(lat, lng) %>% 
      summarize(all_species = paste(unique(stringr::str_to_sentence(species)), collapse = ", "),
                all_confirmed_years = paste(confirmed_year_inc, collapse = ", "),
                wb_name = first(wb_name),
                DOW = first(DOW),
                .groups = "drop_last") %>% 
      distinct(lat, lng, .keep_all = T) %>% 
      ungroup()

    IWF_summs$labels = lapply(seq_len(nrow(IWF_summs)), function(x) {
      paste0("Waterbody: ", IWF_summs$wb_name[x], "<br>",
             "DOW: ", IWF_summs$DOW[x], "<br>",
             "Invader(s): ", IWF_summs$all_species[x], "<br>",
             "Confirmed year(s): ", IWF_summs$all_confirmed_years[x], "<br>")
    })

    bbox = unname(st_bbox(MN))
    
    leaflet(data = IWF_summs) %>% 
      addTiles(options = leaflet::providerTileOptions(minZoom = 6, maxZoom = 15)) %>% 
      addCircleMarkers(lat = ~lat, 
                       lng = ~lng,
                       radius = 5, 
                       group = "infest_lakes", 
                       stroke = T, 
                       color = "black", 
                       weight = 2,
                       opacity = 0.5,
                       fill = T, 
                       fillColor = "#7A0019", 
                       fillOpacity = 0.5,
                       label = ~lapply(labels, HTML)
                      ) %>% 
      addPolygons(data = MN$geometry,
                  stroke = T,
                  color = "black",
                  weight = 3, 
                  opacity = 1, 
                  fill = F) %>% 
      setMaxBounds(lng1 = bbox[1], lat1 = bbox[2], lng2 = bbox[3], lat2 = bbox[4])
    
  })
  
  
  output$infest_graph = renderPlotly({
    
    currDF = IWL_allSources %>% 
      st_drop_geometry() %>% 
      dplyr::select(DOW, species, confirmed_year_inc) %>% 
      filter(!is.na(confirmed_year_inc)) %>% 
      dplyr::group_by(DOW, species) %>% 
      dplyr::summarize(confirmed_year_inc = min(confirmed_year_inc), .groups = "drop") %>% 
      group_by(species, confirmed_year_inc) %>% 
      summarize(n = n(), .groups = "drop") 
    
    #ADD IN A VISUAL TRACE FOR ALL TAXA COMBINED.
    allSppTrace = currDF %>% 
      group_by(confirmed_year_inc) %>% 
      summarize(n = n())
    
    allSppTrace$species = "All"
    
    currDF = bind_rows(allSppTrace, currDF)
    
    #BUT THEN WE NEED TO MAKE ALL THE 0S
    currDFAll = expand.grid(confirmed_year_inc = seq(from = min(currDF$confirmed_year_inc, na.rm = T),
                                                     to = max(currDF$confirmed_year_inc, na.rm = T),
                                                     by = 1), 
                            species = unique(currDF$species))
    
    currDFAll = left_join(currDFAll, currDF, by = c("confirmed_year_inc", "species"))
    currDFAll$n[is.na(currDFAll$n)] = 0
    
    make_infest_graph(currDFAll)
    
  })
  
# ### PROXIES ### ----------------------------------------------------
  
observeEvent(curr_map_sf(), {
  
  map_sf = curr_map_sf()
  
  map_sf$lat = st_coordinates(map_sf)[,2]
  map_sf$lng = st_coordinates(map_sf)[,1]
  
  IWF_summs = map_sf %>% 
    st_drop_geometry() %>% 
    group_by(lat, lng, species) %>% #TO ACCOUNT FOR THE POSSIBILITY THAT TWO DIFFERENT SOURCES HAVE THE SAME TAXON BUT FOR DIFF YEARS, COLLAPSE TO THE EARLIER ONE ACCORDING TO ALL SOURCES AVAILABLE. 
    filter(confirmed_year_inc == min(confirmed_year_inc)) %>% 
    ungroup() %>% 
    group_by(lat, lng) %>% 
    summarize(all_species = paste(stringr::str_to_sentence(species), collapse = ", "),
              all_confirmed_years = paste(confirmed_year_inc, collapse = ", "),
              wb_name = first(wb_name),
              DOW = first(DOW),
              .groups = "drop_last") %>% 
    distinct(lat, lng, .keep_all = T) %>% 
    ungroup()
  
  IWF_summs$labels = lapply(seq_len(nrow(IWF_summs)), function(x) {
    paste0("Waterbody: ", IWF_summs$wb_name[x], "<br>",
           "DOW: ", IWF_summs$DOW[x], "<br>",
           "Invader(s): ", IWF_summs$all_species[x], "<br>",
           "Confirmed year(s): ", IWF_summs$all_confirmed_years[x], "<br>")
  })
  
  leafletProxy("infest_map", session = session) %>% 
    clearMarkers() %>% 
    addCircleMarkers(data = IWF_summs,
                     lat = ~lat, 
                     lng = ~lng,
                     radius = 5, 
                     group = "infest_lakes", 
                     stroke = T, 
                     color = "black", 
                     weight = 2,
                     opacity = 0.5,
                     fill = T, 
                     fillColor = "#7A0019", 
                     fillOpacity = 0.5,
                     label = ~lapply(labels, HTML)
    )
  
  newDF = map_sf %>% 
    st_drop_geometry() %>% 
    dplyr::select(DOW, species, confirmed_year_inc) %>% 
    filter(!is.na(confirmed_year_inc)) %>% 
    dplyr::group_by(DOW, species) %>% 
    dplyr::summarize(confirmed_year_inc = min(confirmed_year_inc), .groups = "drop") %>% 
    group_by(species, confirmed_year_inc) %>% 
    summarize(n = n(), .groups = "drop") 
  
  #ADD IN A VISUAL TRACE FOR ALL TAXA COMBINED.
  allSppTrace = newDF %>% 
    group_by(confirmed_year_inc) %>% 
    summarize(n = n())
  
  allSppTrace$species = "All"
  
  newDF = bind_rows(allSppTrace, newDF)
  
  newDFAll = expand.grid(confirmed_year_inc = seq(from = min(newDF$confirmed_year_inc, na.rm = T),
                                                   to = max(newDF$confirmed_year_inc, na.rm = T),
                                                   by = 1), 
                          species = unique(newDF$species))
  
  newDFAll = left_join(newDFAll, newDF, by = c("confirmed_year_inc", "species"))
  newDFAll$n[is.na(newDFAll$n)] = 0
  
  built = plotly_build(make_infest_graph(newDFAll)) #FAKE-BUILD A NEW VERSION
  
  plotlyProxy("infest_graph", session) %>% 
    plotlyProxyInvoke(
      "react", #THEN PUNCH ITS GENERATED DATA AND OUTPUTS INTO THE OLD GRAPH VIA REACT METHOD.
      built$x$data,
      built$x$layout
    )
    
  
})
  
# ### LOAD MODULES ### ----------------------------------------------------

# ### OBSERVERS ### ---------------------------------------------------------------

  observeEvent(list(input$infest_years, input$infest_spp, input$exclude_conns, input$infest_ctys, input$infest_source, input$exclude_noaccess), {
    
    tmp = IWL_allSources %>% 
      filter(confirmed_year_inc >= input$infest_years[1], 
             confirmed_year_inc <= input$infest_years[2],
             species %in% input$infest_spp,
             if(input$exclude_conns == TRUE) { connected != TRUE } else { TRUE } ,
             grepl(paste(input$infest_ctys, collapse = "|"), counties), #USES OR SYNTAX TO SAY THAT AS LONG AS ANY SELECTED COUNTY GREPLS, KEEP.
             source %in% input$infest_source,
             if(input$exclude_noaccess == TRUE) { DOW %in% pub_accesses } else { TRUE }
             ) 
    
    req(nrow(tmp) > 0) #BAIL IF OVER-FILTERED
    
    curr_map_sf(tmp)
    
  })

}) #End Server Side
