#THE MAIN SERVER FILE IS USUALLY PRETTY SPARSE BECAUSE MUCH OF THE SERVER CODE WILL PROBABLY BE IN MODULE FILES. WHAT EXISTS HERE IS GENERALLY WHAT IS NEEDED TO NAVIGATE BETWEEN TABS/MODULES. 

shinyServer(function(input, output, session) {
  
# REACTIVE VALS -------------------------------------
  
  curr_map_sf = reactiveVal(startingDF) #THIS TRACKS THE CURRENT FILTERED INFESTATIONS LIST ACCORDING TO REGION, WATERBODIES, TIME FRAME, AND TAXA.
  curr_sat_sf = reactiveVal(startingDF) #LESS FILTERED VERSION FOR CALCULATING SATURATION
  habitability_debounced = debounce(reactive({input$habitability_selector}), 350) #THESE OVERREACT A BIT TO SLOW TYPING OTHERWISE  
  known_debounced = debounce(reactive({input$known_selector}), 350)
  map4download = reactiveVal(FALSE) #A COPY OF THE RENDERED MAP
  chgovertime_download = reactiveVal(FALSE) #A COPY OF THE RENDERED CHANGE OVER TIME GRAPH.
  satovertime_download = reactiveVal(FALSE) #A COPY OF THE RENDERED CHANGE IN SATURATION OVER TIME GRAPH.
  
# NON-MODULARIZED SERVER CODE -------------------------------------


## INITIAL INFESTATIONS MAP ------------------------------------------------

  output$infest_map = renderLeaflet({
    
    req(isTruthy(startingDF))
    req(length(which(!is.na(startingDF$year))) > 0) #SAFETY CHECK TO PREVENT OPERATING ON A NON-EXISTANCE DOC
    
    IWL_start = startingDF #START FROM THE INITIAL (FILTERED) INFESTATIONS DATA SET. SEE GLOBAL.R
    
    #PULL OUT LAT LONG SEPARATELY CUZ IT MAKES LEAFLET HAPPIER.
    IWL_start$lat = st_coordinates(IWL_start)[,2]
    IWL_start$lng = st_coordinates(IWL_start)[,1]
    
    IWF_summs = IWL_start %>% 
      st_drop_geometry() %>% 
      filter(year == min(year), .by = c(lat, lng, species)) %>% #TO ACCOUNT FOR THE POSSIBILITY THAT TWO DIFFERENT SOURCES HAVE THE SAME TAXON BUT FOR DIFF YEARS, COLLAPSE TO THE EARLIER ONE ACCORDING TO ALL SOURCES AVAILABLE. 
      filter(year >= startingYear) %>% #AS ELSEWHERE, WE FILTER BY YEAR ONLY AFTER HANDLING THE COLLISIONS.
      summarize(all_species = paste(unique(stringr::str_to_sentence(species)), 
                                    collapse = ", "),
                all_confirmed_years = paste(year, collapse = ", "),
                LAKE_NAME = first(LAKE_NAME),
                DOW = first(DOW),
                .by = c(lat, lng)) %>% 
      distinct(lat, lng, .keep_all = TRUE)

    IWF_summs$labels = lapply(seq_len(nrow(IWF_summs)), function(x) {
      paste0("Waterbody: ", IWF_summs$LAKE_NAME[x], "<br>",
             "DOW: ", IWF_summs$DOW[x], "<br>",
             "Invader(s): ", IWF_summs$all_species[x], "<br>",
             "Confirmed year(s): ", IWF_summs$all_confirmed_years[x])
    })

    bbox = unname(st_bbox(MN))
    
    l = leaflet(data = IWF_summs, 
                options = leafletOptions(keyboard = FALSE)) %>% #PREVENT KEYBOARD NAV
      addTiles(options = leaflet::providerTileOptions(minZoom = 6, maxZoom = 15)) %>% 
      addCircleMarkers(lat = ~lat, 
                       lng = ~lng,
                       radius = 5, 
                       group = "infest_lakes", 
                       stroke = T,
                       color = "black",
                       opacity = 1,
                       weight = 1,
                       fill = T, 
                       fillColor = "#7A0019", 
                       fillOpacity = 0.4,
                       label = ~lapply(labels, HTML)
                      ) %>% 
      addPolygons(data = MN$geometry,
                  stroke = T,
                  color = "black",
                  weight = 2, 
                  opacity = 1, 
                  fill = FALSE) %>% 
      setMaxBounds(lng1 = bbox[1], lat1 = bbox[2], lng2 = bbox[3], lat2 = bbox[4])
    
    session$sendCustomMessage("scrubLeafletMap", list())
    
    map4download(l) #STASH FOR DOWNLOADING
    
    l
    
  })
  
  ## INITIAL INFESTATIONS OVER TIME GRAPH ------------------------------------------------
  
  output$infest_graph = renderPlotly({
    
    IWL_start = startingDF

    currDF = IWL_start %>% 
      st_drop_geometry() %>% 
      dplyr::select(DOW, species, year) %>% 
      dplyr::filter(!is.na(year)) %>% 
      dplyr::summarize(year = min(year), .by = c(DOW, species)) %>% 
      filter(year >= startingYear) %>% #I THINK THIS IS RIGHT?
      dplyr::summarize(n = n(), .by = c(species, year))
    
    #ADD IN A VISUAL TRACE FOR ALL TAXA COMBINED.
    allSppTrace = currDF %>% 
      group_by(year) %>% 
      summarize(n = sum(n))
    allSppTrace$species = "All"
    currDF = bind_rows(currDF, allSppTrace)

    #THEN WE MAKE ALL THE 0S
    currDFAll = expand.grid(year = seq(from = min(currDF$year, na.rm = T),
                                       to = max(currDF$year, na.rm = T),
                                       by = 1), 
                            species = unique(currDF$species))
    
    currDFAll = left_join(currDFAll, currDF, by = c("year", "species"))
    currDFAll$n[is.na(currDFAll$n)] = 0
    
   g = make_infest_graph(currDFAll, spp_pal_all)
   
   chgovertime_download(g)
   
   g
    
  })
  
  ## INITIAL CUMULATIVE SATURATION GRAPH ------------------------------------------------
  
  output$saturation_overtime = renderPlotly({

    currDF_graph = startingDF %>% 
      st_drop_geometry() %>% #NO NEED FOR GEOM
      select(-LAKE_NAME, -connected, -COUNTY, -source) %>% #NO NEED FOR THESE COLUMNS THAT HAVE ALREADY BEEN FILTERED BY, PLUS LAKE_NAME WHICH IS IRRELEVANT
      filter(year == min(year), .by = c(DOW, species)) %>% #ELIMINATE DOWN TO 1 DEFINITIVE RECORD PER LAKE + SPECIES.
      distinct(year, DOW, species, .keep_all = TRUE)
    
    #THERE'S AN EDGE CASE THAT COULD ARISE THAT EMPTIES THE RESULTING OUTPUTS IF ALL THE NEW INFESTATIONS IN A PERIOD WOULD BE 0, SO WE FILL EMPTY YEARS WITH 0S. THIS IS THE START OF THAT
    yearRange = c(startingYear, max(IWL_allSources$year, na.rm = TRUE))
    allYears = data.frame(
      year = seq(
        from = min(c(yearRange[1], currDF_graph$year), na.rm = TRUE),
        to = yearRange[2],
        by = 1
      )
    )
    
    #CALC TOTAL NUMBER OF WATERBODIES IN REGION UNDER CONSIDERATION
    filtered_wbs = lakesDBsimple %>% 
      filter(COUNTY %in% startingCounties)

      #CALC TOTAL NUMBER OF POSSIBLE INFESTATIONS: LAKES * TAXA BEING CONSIDERED
      total_possible_infestations = length(unique(filtered_wbs$DOW)) * length(unique(startingDF$species))
      
      #DECREASE THAT NUMBER ACCORDING TO USER'S HABITAT SUITABILITY ASSUMPTION (AVG. FRACTION OF INVADABLE LAKES)
      user_possible_infestations = total_possible_infestations *
        (startingHabitability/100)
      
      #FOR EACH YEAR, COUNT NUMBER OF UNIQUE DOW * SPECIES COMBOS
      inf_per_year = currDF_graph %>%
        summarize(n = n(), .by = year) %>%
        right_join(allYears, by = "year") %>% #PREVENTS THE EDGE CASE ABOVE AND OTHERWISE IS PRETTY IMMATERIAL
        mutate(n = coalesce(n, 0L)) %>%
        arrange(year)
      
      cumN = cumsum(inf_per_year$n) #NEED TO CUM-SUM THESE.
      cumInf_per_year = data.frame(year = inf_per_year$year, cumN) #KNOWN INFESTATION SATURATION OVER TIME, BASED ON NO MODIFYING ASSUMPTIONS.

      #MODIFY THE CUM INFS BY THE TWO ASSUMPTIONS
      cumInf_per_year$prop_sat_adj = ((cumInf_per_year$cumN * (1 / (startingKnown/100))) / (user_possible_infestations))
    
    cumInf_per_year$tooltip_text = paste0(
      "Year: ", cumInf_per_year$year, "<br>",
      "% infestations of those possible: ", round(cumInf_per_year$prop_sat_adj*100, 2)
    )
    
    cumInf_per_year = cumInf_per_year %>% 
      filter(year >= startingYear) #FILTER TO RESTRICT DISPLAY OF DATA (THO CALCS STILL ACKNOWLEDGE EARLIER INVASIONS)
    
   p = plot_ly(
      data = cumInf_per_year,
      y = ~prop_sat_adj * 100,
      x = ~year,
      color = "#900021", 
      type = "scatter",
      mode = "lines+markers",
      hoverinfo = "text",
      text = ~tooltip_text
    ) %>%
      layout(paper_bgcolor = 'white', 
             plot_bgcolor = 'white',
             xaxis = list(title = "<b>Year</b>",
                          gridcolor = 'lightgrey', 
                          linecolor = "black", 
                          linewidth = 2, 
                          tickfont = list(family = "Open Sans", color='black', size = 14),
                          titlefont = list(family = "Open Sans", color="black", size = 18),
                          fixedrange = TRUE), 
             yaxis = list(title = "% infestations of those thought possible", 
                          linecolor = "black", 
                          linewidth = 2, 
                          tickfont = list(family = "Open Sans", color='black', size = 14),
                          fixedrange = TRUE,
                          range = c(0, 100)
             ))
   
   satovertime_download(p)
   
   output$saturation_caption = renderUI({
       tags$figcaption(
         HTML("Text displaying the approx. % of MN lakes invaded. Calculation:<br>
        (Known infestations (per lake + species) * (1/prop. true known infestations)) / <br>
        ((Lakes * species) * prop. lakes habitable)")
       )
   })
   
   p
    
  })
  
# PROXIES ----------------------------------------------------
  
  ## REMAKE MAP+GRAPH ----------------------------------------------------
  
observeEvent(curr_map_sf(), ignoreInit = TRUE, {

  req(isTruthy(curr_map_sf()))
  req(length(which(!is.na(curr_map_sf()$year))) > 0)
  
  map_sf = curr_map_sf()

  map_sf$lat = st_coordinates(map_sf)[,2]
  map_sf$lng = st_coordinates(map_sf)[,1]
  
  IWF_summs = map_sf %>% 
    st_drop_geometry() %>%  
    filter(year == min(year), .by = c(lat, lng, species)) %>% #TO ACCOUNT FOR THE POSSIBILITY THAT TWO DIFFERENT SOURCES HAVE THE SAME TAXON BUT FOR DIFF YEARS, COLLAPSE TO THE EARLIER ONE ACCORDING TO ALL SOURCES AVAILABLE. 
    summarize(all_species = paste(stringr::str_to_sentence(species), collapse = ", "),
              all_confirmed_years = paste(year, collapse = ", "),
              LAKE_NAME = first(LAKE_NAME),
              DOW = first(DOW),
              .by = c(lat, lng)) %>% 
    distinct(lat, lng, .keep_all = T)
  
  IWF_summs$labels = lapply(seq_len(nrow(IWF_summs)), function(x) {
    paste0("Waterbody: ", IWF_summs$LAKE_NAME[x], "<br>",
           "DOW: ", IWF_summs$DOW[x], "<br>",
           "Invader(s): ", IWF_summs$all_species[x], "<br>",
           "Confirmed year(s): ", IWF_summs$all_confirmed_years[x])
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
                     opacity = 1,
                     weight = 1, 
                     fill = TRUE, 
                     fillColor = "#7A0019", 
                     fillOpacity = 0.4,
                     label = ~lapply(labels, HTML)
    )
  
  #SINCE YOU CAN'T STASH PROXIES, YOU JUST REMAKE THE MAP WHOLE CLOTH HERE AS ABOVE.
  map4download(
    map4download() %>%
      clearMarkers() %>%
      addCircleMarkers(
        data = IWF_summs,
        lat = ~lat,
        lng = ~lng,
        radius = 5,
        group = "infest_lakes",
        stroke = TRUE,
        color = "black",
        opacity = 1,
        weight = 1,
        fill = TRUE,
        fillColor = "#7A0019",
        fillOpacity = 0.4,
        label = ~lapply(labels, HTML)
      )
  )
  
  
  session$sendCustomMessage("scrubLeafletMap", list())
  
  newDF = map_sf %>% 
    st_drop_geometry() %>% 
    dplyr::select(DOW, species, year) %>% 
    dplyr::filter(!is.na(year)) %>% 
    dplyr::summarize(year = min(year), .by = c(DOW, species)) %>% 
    dplyr::summarize(n = n(), .by = c(species, year)) 
  
  spp2use = unique(newDF$species)
  pal2use = spp_pal_one
  
  #ADD IN A VISUAL TRACE FOR ALL TAXA COMBINED.
  if(length(unique(newDF$species)) > 1) {
  allSppTrace = newDF %>% 
    summarize(n = sum(n), .by = year)
  allSppTrace$species = "All"
  newDF = bind_rows(newDF, allSppTrace) #THIS ORDER ENSURES THAT THE ALL WILL BE LAST AND THUS ON TOP
  
  #OVERRIDE TO SWITCH TO NAMES/PALETTES THAT INCLUDE "ALL"
  spp2use = c(spp2use, "All")
  pal2use = spp_pal_all
  
  } 
  
  #ADD IN 0S
  newDFAll = expand.grid(year = seq(from = min(newDF$year, na.rm = T),
                                    to = max(newDF$year, na.rm = T),
                                    by = 1), 
                         species = spp2use)

  newDFAll = left_join(newDFAll, newDF, by = c("year", "species"))
  newDFAll$n[is.na(newDFAll$n)] = 0
  
  built = plotly_build(make_infest_graph(newDFAll, pal2use)) #FAKE-BUILD A NEW VERSION TO GRAB ITS BITS...
  
  plotlyProxy("infest_graph", session) %>% 
    plotlyProxyInvoke(
      "react", #THEN PUNCH THOSE BITS INTO THE OLD GRAPH VIA REACT METHOD.
      built$x$data,
      built$x$layout
    )
  
  chgovertime_download(built) #I THINK I'D JUST SHIP THIS BUILT VERSION...
  
  session$sendCustomMessage("a11yLiveMessage", 
                            "The map and graph have updated based on your new selections.")
    
})
  
# LOAD MODULES ----------------------------------------------------

# OBSERVERS ---------------------------------------------------------------

## UPDATE CURR DF OBSERVER -----------------------------------------------------
  
  observeEvent(
    list(input$infest_years, 
                    input$infest_spp, 
                    input$exclude_conns, 
                    input$infest_ctys, 
                    input$infest_source, 
                    input$exclude_noaccess, 
                    input$exclude_rares
                    ), {
                      
                      if(any(length(input$infest_spp) == 0,
                             length(input$infest_source) == 0,
                             length(input$infest_ctys) == 0)) {
                        output$overfiltering_warning = renderUI({
                          "One of your filter inputs is empty! The map and change in new infestations over time graph reflect your previous selections. "
                        })
                      }
                      
    req(all(length(input$infest_spp) > 0,
            length(input$infest_source) > 0,
            length(input$infest_ctys) > 0))
    
    #FILTER ACCORDING TO ALL USER INPUTS
    tmp = IWL_allSources  %>%
      filter(
             species %in% input$infest_spp,
             if(input$exclude_conns == TRUE) { connected == FALSE } else { TRUE } ,
             COUNTY %in% input$infest_ctys,
             source %in% input$infest_source,
             if(input$exclude_noaccess == TRUE) { DOW %in% pub_accesses } else { TRUE },
             if(input$exclude_rares == TRUE) { species %in% setdiff(unique(species), rares) } else { TRUE } #IF WE'RE EXCLUDING RARES, SPECIES HAS TO BE W/IN SET THAT DOESN'T INCLUDE ANY OF THE RARE ONES.
             ) %>% 
      filter(year == min(year), .by = c(DOW, species)) %>% #MUCH AS IN GLOBAL.R, THIS COMMAND WILL RESOLVE THE COLLISIONS SUCH THAT, OF THE SOURCES SELECTED, ONLY THE VERY FIRST RECORD CHRONOLOGICALLY WILL WIN. WE MUST DO THIS *AFTER* FILTERING BY SOURCE BUT *BEFORE* FILTERING BY YEAR (BELOW)
      distinct(year, DOW, species, .keep_all = TRUE)
    
    if(nrow(tmp) == 0) {
      output$overfiltering_warning = renderUI({
        "No records match your filter selections. The map and change in new infestations over time graph still reflect your previous selections with matches."
      })
    }
    
    req(nrow(tmp) > 0) #BAIL IF OVER-FILTERED
    
    curr_sat_sf(tmp) #FOR THE SATURATION CALC, WHERE FILTERED TO A SELECTED TIME FRAME IS ACTUALLY MISLEADING.
    
    #FOR SOME THINGS, WE APPLY THE YEAR FILTER.
    tmp2 = tmp %>% 
      dplyr::filter(
    year >= input$infest_years[1], 
    year <= input$infest_years[2])
  
    if(nrow(tmp2) == 0) {
      output$overfiltering_warning = renderUI({
        "No records match your filter selections. The map and change in new infestations over time graph still reflect your previous selections with matches."
      })
    }
    
    req(nrow(tmp2) > 0)
    
    output$overfiltering_warning = renderUI({  })
    
    curr_map_sf(tmp2)
    
  })
  
## SATURATION + SAT GRAPH OBSERVER -----------------------------------------------------

  observeEvent(
    list(
         curr_sat_sf(), #<--THIS CHANGES WHENEVER THE OTHER SELECTORS CHANGE, SO IT CAN STAND IN FOR THEM ALL.
         input$infest_spp, #IF YOU SELECT A SPECIES WITH NO RECORDS IN THE SELECTED AREA, THIS DOESN'T CHANGE THE ABOVE FILE BUT OUGHT TO CHANGE THE SATURATION DENOMINATOR.
         input$infest_years, #THIS ONE IS NEEDED TO CHANGE THE X-AXIS SCALE ON THE GRAPH.
         input$infest_ctys, #ALSO CHANGES THE DENOMINATOR (IF A COUNTY HAS NO RECORDS IN THE SELECTED TIME FRAME),
         input$exclude_noaccess, #ALSO CAN CHANGE THE DENOMINATOR BY CREATING A LOT MORE COUNTIES THAT MIGHT BE 0S. 
         habitability_debounced(),
         known_debounced(),
         input$saturation_byarea
    ), 
    priority = -1, { #WE WANT THIS TO RUN ALWAYS *AFTER* THE UPDATE CURR DF OBSERVER RUNS.

      currDF = curr_sat_sf() %>% 
        filter(year <= input$infest_years[2]) #SO ALL MATH INCLUDING THE CURRENT NUMBER IGNORES THINGS PAST THE SELECTED END DATE.
      
      currDF_graph = currDF %>% 
        st_drop_geometry() %>% #NO NEED FOR GEOM
        select(-LAKE_NAME, -connected, -COUNTY, -source) #NO NEED FOR THESE COLUMNS THAT HAVE ALREADY BEEN FILTERED BY, PLUS LAKE_NAME WHICH IS IRRELEVANT
      
      yearRange = input$infest_years
      allYears = data.frame(
        year = seq(
          from = min(c(yearRange[1], currDF_graph$year), na.rm = TRUE),
          to = yearRange[2],
          by = 1
        )
      )
      
    #CALC TOTAL NUMBER OF WATERBODIES IN REGION UNDER CONSIDERATION
    filtered_wbs = lakesDBsimple %>% 
      filter(COUNTY %in% input$infest_ctys)
    
    #REDUCE, IF NEEDED, TO ONLY THOSE W/ PUBLIC ACCESSES.
    if(input$exclude_noaccess) {
      filtered_wbs = filtered_wbs %>% 
        filter(DOW %in% pub_accesses)
    }
    
    #BIFURCATE ACCORDING TO WHETHER WE'RE DOING BY # OR BY AREA
    ##BY NUMBER
    if(!input$saturation_byarea) {
    
    #FOR BOTH: CALC TOTAL NUMBER OF POSSIBLE INFESTATIONS: LAKES * TAXA BEING CONSIDERED
    total_possible_infestations = length(unique(filtered_wbs$DOW)) * length(input$infest_spp)
    
    #DECREASE THAT NUMBER ACCORDING TO USER'S HABITAT SUITABILITY ASSUMPTION (AVG. FRACTION OF INVADABLE LAKES)
    user_possible_infestations = total_possible_infestations *
                                        (input$habitability_selector/100)
    
    #FOR THE GRAPH, FOR EACH YEAR, COUNT NUMBER OF UNIQUE DOW * SPECIES COMBOS
    inf_per_year = currDF_graph %>%
      summarize(n = n(), .by = year) %>%
      right_join(allYears, by = "year") %>% #THIS BIT PREVENTS ANY FULLY 0 YEAR RANGES FROM EFFECTIVELY DISAPPEARING.
      mutate(n = coalesce(n, 0L)) %>%
      arrange(year)
    
    cumN = cumsum(inf_per_year$n) #NEED TO CUM-SUM THESE.
    cumInf_per_year = data.frame(year = inf_per_year$year, cumN) #KNOWN INFESTATION SATURATION OVER TIME, BASED ON NO MODIFYING ASSUMPTIONS.

    #FOR THE CALC, COUNT # OF KNOWN INFESTATIONS 
    known_true_infestations = currDF %>% 
      distinct(DOW, species) %>% #ONLY 1 ROW PER SPECIES AND LAKE!
      nrow()
      
    #THEN INCREASE THAT NUMBER ACCORDING TO USER'S ASSUMPTION ABOUT THE FRACTION OF TRUE INFESTATIONS WE ALREADY KNOW ABOUT. 
    possible_true_infestations = known_true_infestations * (1 / (input$known_selector/100)) #CALC
    
    #THEN CALC ESTIMATED SATURATION: UNKNOWN+KNOWN INFESTATIONS / POSSIBLE INFESTATIONS.
    estimated_saturation = round(
      ((possible_true_infestations / user_possible_infestations) * 100
    ), 2)
    
    #FOR THE GRAPH, MODIFY THE CUM INFS BY THE TWO ASSUMPTIONS
    
    cumInf_per_year$prop_sat_adj = ((cumInf_per_year$cumN * (1 / (input$known_selector/100))) / (total_possible_infestations * (input$habitability_selector/100)))
    
    cumInf_per_year$tooltip_text = paste0(
          "Year: ", cumInf_per_year$year, "<br>",
          "% infestations of those possible: ", round(cumInf_per_year$prop_sat_adj*100, 2)
        )
    
    #JUST DON'T PLOT THE DATA FROM OUTSIDE THE YEAR RANGE SELECTED, BUT HAVE IT REMAIN INTEGRATED INTO THE MATH
    cumInf_per_year = cumInf_per_year %>% 
      filter(year >= input$infest_years[1])
  
    plotlyProxy("saturation_overtime", session) %>% 
      plotlyProxyInvoke(
        "restyle",
        list(x = list(cumInf_per_year$year),
             y = list(round(cumInf_per_year$prop_sat_adj*100, 2)),
             hoverinfo = "text",
             text = list(cumInf_per_year$tooltip_text)),
        list(0)
      ) %>% 
      plotlyProxyInvoke(
        "relayout",
        list(yaxis = list(
          title = "% infestations of those thought possible", 
          linecolor = "black", 
          linewidth = 2, 
          tickfont = list(family = "Open Sans", color='black', size = 14),
          fixedrange = TRUE,
          range = c(0, 100)
        ),
        xaxis = list(title = "<b>Year</b>",
                     gridcolor = 'lightgrey', 
                     linecolor = "black", 
                     linewidth = 2, 
                     tickfont = list(family = "Open Sans", color='black', size = 14),
                     titlefont = list(family = "Open Sans", color="black", size = 18),
                     range = c(min(cumInf_per_year$year), max(cumInf_per_year$year)),
                     fixedrange = TRUE))
      )
    
    satovertime_download(plot_ly(
      data = cumInf_per_year,
      y = ~prop_sat_adj * 100,
      x = ~year,
      color = "#900021", 
      type = "scatter",
      mode = "lines+markers",
      hoverinfo = "text",
      text = ~tooltip_text
    ) %>%
      layout(paper_bgcolor = 'white', 
             plot_bgcolor = 'white',
             xaxis = list(title = "<b>Year</b>",
                          gridcolor = 'lightgrey', 
                          linecolor = "black", 
                          linewidth = 2, 
                          tickfont = list(family = "Open Sans", color='black', size = 14),
                          titlefont = list(family = "Open Sans", color="black", size = 18),
                          range = c(min(cumInf_per_year$year), max(cumInf_per_year$year)),
                          fixedrange = TRUE), 
             yaxis = list(title = "% infestations of those thought possible", 
                          linecolor = "black", 
                          linewidth = 2, 
                          tickfont = list(family = "Open Sans", color='black', size = 14),
                          fixedrange = TRUE,
                          range = c(0, 100)
             )))
    
    } else {
      
      #CALC TOTAL INFESTABLE AREA ***EXCLUDING SUPERIOR
      total_area_infestable = sum(filtered_wbs$LAKE_SIZE[filtered_wbs$DOW != "16000100"]) * length(input$infest_spp)
      
      #DECREASE BY HABITABILITY ASSUMPTIONS
      user_possible_area_infestable = total_area_infestable * (input$habitability_selector/100)

      #SUM UP ALL THE LAKE SIZES TO GET TOTAL KNOWN INFESTED AREA, AGAIN ***EXCLUDING SUPERIOR
      known_true_infestations = currDF %>% 
        distinct(DOW, species, LAKE_SIZE) %>% 
        filter(DOW != "16000100")
      
      #THESE CALCS PROCEED MUCH AS ABOVE. 
      total_known_infested_area = sum(known_true_infestations$LAKE_SIZE)
      
      possible_true_infested_area = total_known_infested_area * (1 / (input$known_selector/100))
      
      estimated_saturation = round(
        ((possible_true_infested_area / user_possible_area_infestable) * 100
        ), 2)
      
      #FOR THE GRAPH, FOR EACH YEAR, SUM TOTAL AREA OF DOW * SPECIES COMBOS
      inf_per_year_area = currDF_graph %>%
        filter(DOW != "16000100") %>%
        summarize(area = sum(LAKE_SIZE), .by = year) %>%
        right_join(allYears, by = "year") %>% #PREVENTS ANY ALL 0 NEW INFESTATION WINDOWS FROM DISAPPEARING BY LOSING DIMENTIONALITY. 
        mutate(area = coalesce(area, 0)) %>%
        arrange(year)
      
      cumArea = cumsum(inf_per_year_area$area) #NEED TO CUM-SUM THESE.
      cumArea_per_year = data.frame(year = inf_per_year_area$year, cumArea) #KNOWN INFESTATION SATURATION OVER TIME, BASED ON NO MODIFYING ASSUMPTIONS.
      
      #MODIFY THE CUM AREAS BY THE TWO ASSUMPTIONS
      cumArea_per_year$cumArea_adj = ((cumArea_per_year$cumArea * (1 / (input$known_selector/100))) / user_possible_area_infestable)
      
        cumArea_per_year$tooltip_text = paste0(
          "Year: ", cumArea_per_year$year, "<br>",
          "% infestated area of that thought possible: ", round(cumArea_per_year$cumArea_adj*100, 2)
        )
        
        #JUST DON'T PLOT THE DATA FROM OUTSIDE THE YEAR RANGE SELECTED, BUT HAVE IT REMAIN INTEGRATED INTO THE MATH
        cumArea_per_year = cumArea_per_year %>% 
          filter(year >= input$infest_years[1])
      
      plotlyProxy("saturation_overtime", session) %>% 
        plotlyProxyInvoke(
          "restyle",
          list(x = list(cumArea_per_year$year),
               y = list(round(cumArea_per_year$cumArea_adj*100,2)),
               hoverinfo = "text",
               text = list(cumArea_per_year$tooltip_text)),
          list(0)
        ) %>% 
        plotlyProxyInvoke(
          "relayout",
          list(yaxis = list(
            title = "% infestated area of that thought possible",
            linecolor = "black", 
            linewidth = 2, 
            tickfont = list(family = "Open Sans", color='black', size = 14),
            fixedrange = TRUE,
            range = c(0, 100)
          ),
          xaxis = list(title = "<b>Year</b>",
                       gridcolor = 'lightgrey', 
                       linecolor = "black", 
                       linewidth = 2, 
                       tickfont = list(family = "Open Sans", color='black', size = 14),
                       titlefont = list(family = "Open Sans", color="black", size = 18),
                       range = c(min(cumArea_per_year$year), max(cumArea_per_year$year)),
                       fixedrange = TRUE))
        )
      
      satovertime_download(plot_ly(
        data = cumArea_per_year,
        y = ~cumArea_adj * 100,
        x = ~year,
        color = "#900021", 
        type = "scatter",
        mode = "lines+markers",
        hoverinfo = "text",
        text = ~tooltip_text
      ) %>%
        layout(paper_bgcolor = 'white', 
               plot_bgcolor = 'white',
               xaxis = list(title = "<b>Year</b>",
                            gridcolor = 'lightgrey', 
                            linecolor = "black", 
                            linewidth = 2, 
                            tickfont = list(family = "Open Sans", color='black', size = 14),
                            titlefont = list(family = "Open Sans", color="black", size = 18),
                            range = c(min(cumArea_per_year$year), max(cumArea_per_year$year)),
                            fixedrange = TRUE), 
               yaxis = list(title = "% infestated area of that thought possible", 
                            linecolor = "black", 
                            linewidth = 2, 
                            tickfont = list(family = "Open Sans", color='black', size = 14),
                            fixedrange = TRUE,
                            range = c(0, 100)
               )))

    }
    
    #PRESENT CALC-ED SATURATION TEXT
    output$saturation_percentage = renderText({
      paste0(estimated_saturation, "%")
    })
    
    #GUARDRAILS TO PREVENT TEMPORARILY EMPTY INPUTS OR OTHERWISE INVALID CALCULATIONS. 
    req(!is.na(estimated_saturation)) 
    req(!is.nan(estimated_saturation)) 
    req(is.finite(estimated_saturation))
    
    #MAKE CONTEXT-APPROPRIATE CAPTION.
    output$saturation_caption = renderUI({
      if(!input$saturation_byarea) {
      tags$figcaption(
        HTML("Text displaying the approx. % of MN lakes invaded. Calculation:<br>
        (Known infestations (per lake + species) * (1/prop. true known infestations)) / <br>
        ((Lakes * species) * prop. lakes habitable)")
      )
      } else {
        tags$figcaption(
        HTML("Text displaying the approx. % of MN lake area invaded. Calculation:<br>
        (Known infested area (area/lake * # species/lake) * (1/prop. true known infestations)) / <br>
        ((Total lake area * species) * prop. lake area habitable)")
        )
      }
    })
    
    #AND SAME W/ A FIGURE CAPTION.
    output$saturation_figcaption = renderUI({
      if(!input$saturation_byarea) {
        tags$figcaption(
          "Line graph showing the change in total invasion saturation, in proportion of invasions per taxon per lake, over time for the lakes and taxa selected, based on your assumptions."
        )
      } else {
        tags$figcaption(
          "Line graph showing the change in total invasion saturation, in proportion of invaded area per taxon per lake, over time for the lakes and taxa selected, based on your assumptions."
        )
      }
    })
    
    #DETERMINE CONTEXT TEXT TO REPORT
    if(estimated_saturation > 100) {
      
      output$saturation_context = renderText({
        "That's obviously too high, based on what we know we know! Tone down your other assumptions."
      })
      
      session$sendCustomMessage("a11yLiveMessage", 
                                "That's obviously too high, based on what we know we know! Tone down your other assumptions.")
      
    } else {
      
      if(estimated_saturation < 5) { message = "If your assumptions are true, AIS spread prevention would be immensely valuable, as nearly all lakes are almost wholly uninvaded by the taxa under consideration."}
      
      if(estimated_saturation >= 5 & estimated_saturation < 10) { message = "If your assumptions are true, AIS spread prevention would be very valuable, as many lakes are entirely or mostly uninvaded by the taxa under consideration."}
      
      if(estimated_saturation >= 10 & estimated_saturation < 25) { message = "If your assumptions are true, AIS spread prevention would be valuable, as many new invasions are still possible."}
      
      if(estimated_saturation >= 25 & estimated_saturation < 50) { message = "If your assumptions are true, AIS spread prevention may still be valuable, as many lakes are still susceptible to some new invasions."}
      
      if(estimated_saturation >= 50 & estimated_saturation < 80) { message = "If your assumptions are true, AIS spread prevention may still be somewhat valuable, as some lakes are still susceptible to a few new invasions."}
      
      if(estimated_saturation >= 80) { message = "If your assumptions are true, AIS spread prevention may have relatively little value; most lakes are already largely or fully invaded by the taxa under consideration."}
      
      output$saturation_context = renderText({
       message
      })
      
      session$sendCustomMessage("a11yLiveMessage", 
                                message)
      
  }
})
  
## EXCLUDE TAXA OBSERVER -----------------------------------------------------
  
observeEvent(input$exclude_rares, {

  #ONLY EXCLUDE IF YES; DON'T AUTO-INCLUDE WHEN UNCHECKED. MAKE THEM DO THAT MANUALLY.
  if(input$exclude_rares) {
  newSpp = setdiff(input$infest_spp, rares) #PULL FROM THOSE THAT ARE ALREADY SELECTED AND REMOVE FROM THOSE THE RARE ONES.
  updatePickerInput(session = session, inputId = "infest_spp", selected = newSpp)
  }
  
})
  
## RESTRICT NUMERIC INPUTS OBSERVERs -----------------------------------------------------
  
  #OTHERWISE, YOU CAN OVERRIDE THE MIN/MAX WITH A KEYBOARD
  observeEvent(input$known_selector, priority = 2, {
    
    req(isTruthy(input$known_selector))
    
    if(input$known_selector > 100) {
      updateNumericInput(session, "known_selector", value = 100)
    }
    
    if(input$known_selector < 0) {
      updateNumericInput(session, "known_selector", value = 0)
    }
    
  })
  
  observeEvent(input$habitability_selector, priority = 2, {
    
    req(isTruthy(input$habitability_selector))
    
    if(input$habitability_selector > 100) {
      updateNumericInput(session, "habitability_selector", value = 100)
    }
    
    if(input$habitability_selector < 0) {
      updateNumericInput(session, "habitability_selector", value = 0)
    }
    
  })
  
# DOWNLOAD HANDLERS----------------------------------------------------
  
## INVASIVE SPP LIST -------------------------------------------------------

  output$invasives_list = downloadHandler(
    filename = "BtS_invasive_species_list.csv",
    function(file) {
      write.csv(allInvasivesList, file, row.names = FALSE)
    }
  )
  
## MAP RECORDS -------------------------------------------------------
  
  output$download_map_records = downloadHandler(
    filename = "BtS_map_records.csv",
    function(file) {
      write.csv(isolate(curr_map_sf()), file, row.names = FALSE)
    }
  )
  
  ## MAP HTML -------------------------------------------------------
  
  output$map_HTML_download = downloadHandler(
    function() {
      paste0("BtS_", Sys.Date(), "_map.html")
    },
    function(file) {
      req(map4download())
      htmlwidgets::saveWidget(map4download(), file, selfcontained = TRUE)
    }
  )
  
  ## CHG OVER TIME GRAPH -------------------------------------------------------
  
  output$chgovertime_download = downloadHandler(
    function() {
      paste0("BtS_", Sys.Date(), "_chgOverTimeGraph.html")
    },
    function(file) {
      req(chgovertime_download())
      htmlwidgets::saveWidget(chgovertime_download(), file, selfcontained = TRUE)
    }
  )
  
  ## SATURATION OVER TIME GRAPH -------------------------------------------------------
  
  output$satovertime_download = downloadHandler(
    function() {
      paste0("BtS_", Sys.Date(), "_satOverTimeGraph.html")
    },
    function(file) {
      req(satovertime_download())
      htmlwidgets::saveWidget(satovertime_download(), file, selfcontained = TRUE)
    }
  )

}) #End Server Side
