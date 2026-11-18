#IT'S USEFUL TO WRAP EVERYTHING IN THE UI IN A FLUIDPAGE BECAUSE FLUIDPAGE CAN HANDLE BEING STUFFED FULL OF SHINY ADMINISTRATIVE CODE, WHEREAS OTHER UI ELEMENTS LIKE NAVBARPAGE DOESN'T LIKE THEM. 
ui = fluidPage(
  id = "whole_page",
  
  title = "Beating the Spread", #THIS IS THE TEXT THAT'LL GO IN THE BROWSER TAB FOR YOUR USER WHEN YOUR APP IS OPEN.
  
  tags$html(lang = "en"), #SET THE PAGE LANGUAGE TO ENGLISH FOR SCREEN READERS. MUST BE DONE AS "HIGH" IN THE APP STRUCTURE AS POSSIBLE!
  
# LOAD IN OUTSIDE FILES -----------------------------------------
  
  #LOAD IN OUR STYLE SHEET.
 tags$head(
    tags$link(
    rel = "stylesheet", 
    type = "text/css",
    href = "BtSCSS.css" #OR WHATEVER YOU RENAME THIS FILE TO.
  ),
  

# LOAD IN JS SCRIPTS ----------------------------

  #LOAD IN GOOGLE ANALYTICS SCRIPT, IF USING.
    shiny::tags$script(
      src = "https://www.googletagmanager.com/gtag/js?id=G-xxxxx", #YOU WILL NEED TO GET ONE OF THESE G-TAGS FROM GOOGLE ANALYTICS
      async = ""
    ),

    shiny::tags$script(
      src = "js/googleanalytics.js" #PLACE THE G-TAG IN THE CODE PROVIDED HERE ALSO.
    ),
  
  #LOAD CUSTOM SCRIPT THAT PREVENTS USERS FROM INPUTTING NEGATIVES OR ES INTO NUMERIC INPUTS (DISABLE IF NOT APPLICABLE.)
    tags$script(
      src = "js/numInputsPreventNegsE.js"
    ),

#UPON DISCONNECT, ENSURE THAT FOCUS SHIFTS TO THE CUSTOM DISCONNECT MESSAGE AND THAT TEXT IS INSERTED INTO THE REFRESH LINK.
tags$script(
  src = "js/shiftFocusOnDisconnect.js"
),

#GENERATE A FUNCTION THAT ALLOWS JS AND SHINY TO SEND MESSAGES TO THE ARIA LIVE REPORTING REGION TO BE REPORTED TO SCREEN-READER USERS.
tags$script(
  src = "js/shinyLiveReportingRegion.js"
),

#THIS SCRIPT ENSURES THAT EVERY TIME THE LEAFLET MAP GETS REBORN ON THIS PAGE, IT GETS ARIA-HIDDEN AND LOSES KEYBOARD NAV.
tags$script(HTML("
  function scrubLeafletAccessibility() {
    var tries = 0;
    var maxTries = 20;

    var interval = setInterval(function() {
      var mapContainer = document.getElementById('infest_map');
      if (!mapContainer) {
        tries++;
        if (tries >= maxTries) clearInterval(interval);
        return;
      }

      // Confirm map is rendered enough to modify
      var leafletSVG = mapContainer.querySelector('svg.leaflet-zoom-animated');

      if (leafletSVG || tries >= maxTries) {
        // Remove ARIA and tabindex from container
        mapContainer.setAttribute('aria-hidden', 'true');
        mapContainer.setAttribute('tabindex', '-1');
        mapContainer.removeAttribute('aria-live');

        // Remove all tabbable children (zoom buttons, links, etc.)
        var focusables = mapContainer.querySelectorAll('a, button, [tabindex]');
        focusables.forEach(function(el) {
          el.setAttribute('tabindex', '-1');
          el.setAttribute('aria-hidden', 'true');
        });

        clearInterval(interval);
      }

      tries++;
    }, 300);
  }

  // Run once Shiny has booted
  document.addEventListener('DOMContentLoaded', function() {
    // Also re-run if map is re-rendered (optional hook if dynamic)
    Shiny.addCustomMessageHandler('scrubLeafletMap', function(msg) {
      scrubLeafletAccessibility();
    });

    // Run it now (initial map load)
    scrubLeafletAccessibility();
  });
")),
            
tags$script(HTML("
      $(function () {
        $('[data-toggle=\"popover\"]').popover({container: 'body'});
      });
    "))         
),

# ### ENABLING OPTIONAL FUNCTIONALITY ### ------------------------------------------

#SOME SHINY-AFFILIATED PACKAGES NEED TO HAVE THEIR FEATURES "ENABLED" IN THE UI. I PUT THOSE FUNCTION CALLS HERE. COMMENT OUT OR DELETE IF THE ASSOCIATED PACKAGES AREN'T BEING USED.

waiter::useWaiter(), #NECESSARY TO TURN ON THE WAITER PACKAGE'S FEATURES.
shinyjs::useShinyjs(), #ENABLE SHINYJS


#   ### ADD POLISHING UI ELEMENTS ### -------------------------------------

  #USING THE SHINYDISCONNECT PACKAGE, WE CAN SET A CUSTOM DISCONNECT MESSAGE SO IT'S ABUNDANTLY CLEAR TO USERS THAT THE APP HAS CLOSED (IT'S NOT OBVIOUS OTHERWISE). 
disconnectMessage(text = " ",  #THIS DOESN'T MATTER AS WE'RE GONNA REPLACE IT WITH A JS SCRIPT ANYWAY.
                  refresh = "Refresh the page", 
                  width = "full", 
                  top = "center", 
                  size = 22, 
                  background = "#7a0019", 
                  colour = "white", 
                  refreshColour = "#ffb71e", 
                  css = "z-index: 100000 !important;"),

#USING THE WAITER PACKAGE, WE CAN ADD IN A "PRELOADER WAITER" THAT SITS ON SCREEN WHILE THE APP BOOTS UP, WHICH IS REALLY ONLY NECESSARY IF START-UP TAKES KIND OF A WHILE. 
   waiter::waiter_preloader(html = shiny::tagList(
     waiter::spin_loaders(6), shiny::br(), shiny::br(),
     shiny::HTML("Spreading out..."), #Provides more text so that it doesn't need to go into the alt text.
     shiny::br(), shiny::br(),
     shiny::img(src = "maisrc-white.png", alt = "")
   ), #THIS ALT CAN BE EMPTY--THE TEXT ABOVE CONVEYS ALL NECCESSARY INFO. 
   color = "#7a0019",
   fadeout = 500
),


# ### CORE APP UI ELEMENTS ### --------------------------------------------

## ### HEADER, H1, NAV ### -------------------------------------------------

#THE FIRST ELEMENT OF THE PAGE SHOULD PROBABLY BE A HEADER, IF APPLICABLE. 
tags$header(
    class = "flexthis flexcol width100 justifycenter flexwrap",
    #THE TITLE OF THE APP SHOULD BE IN THE HEADER, AND PROBABLY ALSO BEAR THE H1 TAG.
    h1(tagList(
      img(src = "maisrc-black.png",
          alt = "MAISRC logo.",#THIS ALT SHOULD JUST BE THE TEXT SIGHTED PERSONS WOULD SEE HERE.
          style = "min-width: 320px; max-height: 75px;"),
      img(src = "beating-the-spread.png",
          alt = "Beating the Spread",#THIS ALT SHOULD JUST BE THE TEXT SIGHTED PERSONS WOULD SEE HERE.
          style = "min-width: 320px; max-height: 200px;")
    )
), 
    #IF THERE'S A NAV BAR IN THE HEADER, IT SHOULD BEAR THIS SEMANTIC TAG.
    class = "flexthis flexcol width100 justifycenter flexwrap",
    tags$nav( 
      class = "flexthis flexwrap justifycenter"
   )
),


## ### MAIN CONTENT/MODULES ### --------------------------------------------

tags$main(
  id = "map_main",
  
### INFESTATION MAP DIV ---------------------------------------------------------

tags$section(
  id = "infest_map_div",
  h2("Which invaders have been documented at which waterbodies?"),
  
  #### INFESTATION MAP ---------------------------------------------------------
  tags$figure(
    tags$figcaption("Map showing waterbodies (points) with credible, documented observations of invaders, given your current filters (see next section). Hover points for more information."),
    downloadButton("download_map_records", 
                   label = HTML("Download the data as CSV."), 
                   icon = NULL, 
                   class = "link-style-btn", 
                   style = "padding: 0; border: none; background: none; cursor: pointer; text-align: left; margin-bottom: 10px; display: inline; margin-left: auto; margin-right: auto; text-wrap: wrap;"),
    br(),
    downloadButton("map_HTML_download", 
                   label = HTML("Download the map as HTML."), 
                   icon = NULL, 
                   class = "link-style-btn", 
                   style = "padding: 0; border: none; background: none; cursor: pointer; text-align: left; margin-bottom: 10px; display: inline; margin-left: auto; margin-right: auto; text-wrap: wrap;"),
    leafletOutput("infest_map", width = "100%", height = "450px"),
  )
),

hr(),
br(),

### SCOPE FILTERING FIELDSET ---------------------------------------------------------

tags$section(
  id = "scope_filtering_div",
  h2("Which waterbodies and taxa are we considering?"),
  
  uiOutput("overfiltering_warning"), 
  
tags$fieldset(
  tags$legend("Control which infestations, waterbodies, and invaders are considered throughout the dashboard."),
  
  fluidRow(
    style = "width: 100%;",
    
    column(width = 4, offset = 1, 
           
           pickerInput("infest_spp", 
                       label = div("Invader(s)",
                                   make_tooltip(
                                     tooltipText = tagList(
                                       downloadLink("invasives_list",
                                                    label = "Download a CSV of the taxa MAISRC considers invasive this dashboard."),
                                       tags$span("Our criteria for inclusion were as follows:"),
                                       tags$ul(
                                         tags$li("An established population at a waterbody can be reasonably inferred by even a single credible observation. Observations should not regularly represent visitors, transients, or released organisms that are unlikely to survive."),
                                         tags$li("Once so established, a population is unlikely to disappear without eradication effort, which ought to be considerable."),
                                         tags$li("The taxon can plausibly survive Minnesota winters and reproduce here, via whatever means needed to sustain a population."),
                                         tags$li("The concensus amongst AIS entities in the state recognize the taxon as invasive and not merely as non-native."),
                                         tags$li("The taxon would warrant a concommitant respose, such as surveillance, prevention, containment, control, or quarantine efforts."),
                                         tags$li("The taxon is an aquatic invader insofar as it is managed as one.")
                                       ),
                                       tags$span("It's not a requirement that the taxon already be documented as present within the state. Also, for simplicity, some taxa, such as narrow-leaf and hybrid cattails, are treated as a single taxon for the purposes of the dashboard even though, from a management perspective, they are often treated very differently.")
                                     )
                                   )),
                       choices = taxa2pick, #SEE GLOBAL.R
                       selected = unique(startingDF$species), #SEE GLOBAL.R.
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           stripPickerDuplicateTitles("infest_spp"),
           suppressNativeSelectAccessibility("infest_spp"),
           
           pickerInput("infest_ctys", 
                       label = "County(ies)",
                       choices = startingCounties, 
                       selected = startingCounties, 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           stripPickerDuplicateTitles("infest_ctys"),
           suppressNativeSelectAccessibility("infest_ctys"),
           
           pickerInput("infest_source", 
                       label = "Source database(s)",
                       choices = sort(unique(IWL_allSources$source)), 
                       selected = unique(IWL_allSources$source), 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           stripPickerDuplicateTitles("infest_source"),
           suppressNativeSelectAccessibility("infest_source"),
           
           pickerInput("wb_types", 
                       label = "Waterbody types (as designated by the MN DNR)",
                       choices = sort(unique(IWL_allSources$wb_class)), 
                       selected = startingWBTypes, 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           stripPickerDuplicateTitles("wb_types"),
           suppressNativeSelectAccessibility("wb_types"),
           
    ), #END FIRST COL
    
    column(width = 4, offset = 2, 
  
  sliderInput("infest_years", 
              label = div("Year of first documented (re-)establishment",
                          make_tooltip(tooltipText = tagList(
                            tags$span("We define an invader as \"established\" in a waterbody once any credible observation is made at that waterbody (or within 50 meters of its edge) across any of the sources selected, with the year of that first credible observation being what this slider filters by."), 
                            br(), 
                            tags$span("However, if any credible extirpation events were documented at a waterbody, the year of documented establishment becomes the first year subsequent to the last of these events. A credible extirpation event is defined differently by source:", 
                            tags$ol(
                              tags$li("PI Charter: A complete survey in a year subsequent to documentation fails to detect the taxon at even a single point"),
                              tags$li("NAS: \"status\" values of \"failed\", \"extirpated\", and/or \"eradicated\" at all observed points within 50 meters of the waterbody in a given year."),
                              tags$li("EDDMapS:  \"infestationstatus\" of \"eradicated\" and/or \"managementstatus\" of \"possibly eradicated\" at all observed points within 50 meters of the waterbody in a given year.")))))), 
              min = min(IWL_allSources$year, na.rm=T), 
              max = max(IWL_allSources$year, na.rm=T), 
              step = 1, 
              value = c(startingYear, max(IWL_allSources$year, na.rm=T)), #SEE GLOBAL.R FOR STARTINGYEAR VALUE.
              sep = ""
  ),
  
  checkboxInput("exclude_conns", 
                label = div("Exclude records listed due to connections with other waterbodies only.", make_tooltip(tooltipText = tagList(
                  tags$span("Statute states waterbodies connected to infested waterbodies are infested, whether or not this has been independently confirmed (and such confirmations rarely occur)."), 
                  tags$a(href = 'https://www.revisor.mn.gov/statutes/cite/84d.03', target = '_blank', "See the statute for more details."), 
                  tags$span("Only applies to the Infested Waters List.")))), 
                value = FALSE),
  
  checkboxInput("exclude_last_unknowns", 
                label = div("Exclude records whose only observations had \"unknown\" status.", 
                make_tooltip(tooltipText = tagList(
                             tags$span("The Nonindigenous Aquatic Species database categorizes observations into various \"status\" categories. Among these is \"unknown\", which it treats differently and as more uncertain than its \"collected\", \"established\", \"eradicated\" and other categories. As such, MAISRC does not currently consider observations marked with this status as definite vis-a-vis those with a \"collected\" or \"established\" status and encourages their exclusion."), 
                             tags$a(href = "https://nas.er.usgs.gov/about/faq.aspx#status", target = "_blank", "See their metadata for more details."),
                             tags$span("Only relevant for the NAS database.")))), 
                value = TRUE),
  
  checkboxInput("exclude_small_wbs", 
                label = "Restrict to waterbodies >= 10 acres (according to the MN DNR's hydrography database).", 
                value = excludeSmallStart),
  
  checkboxInput("exclude_noaccess", 
                label = "Exclude waterbodies without public motorized boat launches (according to the MN DNR's database).", 
                value = FALSE),
  
  checkboxInput("exclude_rares",
                label = "Exclude taxa with few (< 10 different waterbodies) documented observations to date",
                value = excludeRaresStart)

     ) #END SECOND COL
   ) #END FLUID ROW
  ) #END FIELD SET

 ), #END SCOPE FILTERING DIV

hr(),
br(),

### CHANGE GRAPH DIV ---------------------------------------------------------

tags$section(
  id = "infest_graph_div",
  h2("How have rates of new infestations changed over time?"),
  
  #### CHANGE GRAPH ---------------------------------------------------------
  tags$figure(
    tags$figcaption("Line graph showing numbers of new documented cases (y-axis) per year (x-axis) by invader (colors). Hover lines for more info. Double-click legend keys to select single species; single-click to remove species."),
    downloadButton("chgovertime_download", 
                   label = HTML("Download current graph as HTML."), 
                   icon = NULL, 
                   class = "link-style-btn", 
                   style = "padding: 0; border: none; background: none; cursor: pointer; text-align: left; margin-bottom: 10px; display: inline; margin-left: auto; margin-right: auto; text-wrap: wrap;"),
    plotlyOutput("infest_graph", width = "100%", height = "500px")
  ) #END FIG
), #END GRAPH DIV

hr(),
br(),

### SATURATION DIV ---------------------------------------------------------

tags$section(
  id = "saturation_div",
  h2("How \"invasion saturated\" are Minnesota's waterbodies?"),
  
  #### SATURATION EXPLANATION ---------------------------------------------------------
  tags$section(
    p("Prevention can only work when there's something left to prevent! What fraction of Minnesota's waterbodies  haven't", em("yet"), "been invaded but remain invadable? Or, said differently, \"How close to fully invaded\" are we?"),
    p("The answer hinges on three factors: "),
    tags$ul(
      tags$li("Which waterbodies, regions, and taxa are we considering? (Here, we'll respect your selections in the earlier section)"),
      tags$li("What fraction of waterbodies is actually \"invadable?\" (you'll set that assumption in this section), and"),
      tags$li("Do we know about all invasions, or is there some fraction we don't yet know about? (you'll set this assumption in this section too)")
    ),
    p("We know the percentage of waterbodies that are inhabitable is less than 100% and varies by species. Research (Kanankege",
      em("et al."), "2019 (",
      a("see here",
        href = "https://www.researchgate.net/publication/344694872_The_use_of_spatiotemporal_analytical_tools_to_inform_decisions_and_policy_in_One_Health_scenarios",
        target = "_blank",
        rel = "noopener"
      ),
      ") and Muthukrishnan",
      em("et al."),
      "2018 (",
      a("see here",
        href = "https://doi.org/10.1016/j.aquabot.2018.08.001",
        target = "_blank",
        rel = "noopener"
      ),
      ")) suggests the percentages of lakes inhabitable by zebra mussel, starry stonewort, and Eurasian watermilfoil lie between 30-70%, for example."
    ),
    p(
      "We also know AIS surveillance catches less than 100% of all extant infestations, especially new ones. Because we can only count infestations we know about, estimating the number of infestations we", em("don't"), " know about is important. One older estimate from Wisconsin (Latzka",
      em("et al."),
      "2013 (",
      a("see here",
        href = "https://www.researchgate.net/publication/267290078_How_invaded_are_we_really_Aquatic_invasive_species_occurrence_datasets_under-represent_species_distributions_and_misinform_predictive_models",
        target = "_blank",
        rel = "noopener"
      ),
      ")) put the percentage of infestations we don't know about as high as 75%! That'd mean there are 4x as many infestations as have been documented so far; we'd like to think that's not true in Minnesota, but we don't know for sure."
    )
  ),
  fluidRow(
    column(width = 4, offset = 1,
           
  #### SATURATION ASSUMPTIONS ---------------------------------------------------------
  tags$fieldset(
    tags$legend("Use these toggles to set assumptions about how invadable MN waterbodies are, on average, and how many invasions have been documented. Use selectors elsewhere to control which taxa, regions, and waterbodies are included."),
    numericInput("habitability_selector",
                 label = "% of waterbodies habitable", 
                 value = startingHabitability, #SEE GLOBAL.R
                 min = 0, 
                 max = 100, 
                 step = 1
                 ),
    numericInput("known_selector",
                 label = "% of true infestations documented", 
                 value = startingKnown, #SEE GLOBAL.R
                 min = 0, 
                 max = 100, 
                 step = 1
                 ),
    checkboxInput("saturation_byarea",
                  label = "Calculate invasion saturation by total waterbody area instead", 
                  value = FALSE)
   )
  ), #END COL 1
  column(width = 4, offset = 1,
         
    #### SATURATION ESTIMATE ---------------------------------------------------------
    tags$figure(
      uiOutput("saturation_caption"),
      textOutput("saturation_percentage"),
      textOutput("saturation_context")
    )
  ) #END COL 2
 ), #END FLUID ROW
 fluidRow(
   #### SATURATION OVER TIME GRAPH ---------------------------------------------------------
   tags$figure(
     uiOutput("saturation_figcaption"),
     downloadButton("satovertime_download", 
                    label = HTML("Download current graph as HTML."), 
                    icon = NULL, 
                    class = "link-style-btn", 
                    style = "padding: 0; border: none; background: none; cursor: pointer; text-align: left; margin-bottom: 10px; display: inline; margin-left: auto; margin-right: auto; text-wrap: wrap;"),
     plotlyOutput("saturation_overtime")
   )
 )
),

hr(),
br(), 

), #END MAIN

## ### FOOTER ### ----------------------------------------------------------

#Insert a footer with links, contact info, funding credits, and current version number.
tags$footer(
HTML("<br>Beating The Spread was created by the Minnesota Aquatic Invasive Species Research Center at the University of Minnesota by <address><a href='mailto:bajcz003@umn.edu'>Dr. Alex Bajcz (bajcz003@umn.edu)</a></address>.<br>
App last updated Nov. 18 2026. Version 0.0.11.<br>
Funding for this work was provided by the Minnesota Environment and Natural Resources Trust Fund as recommended by the Minnesota Aquatic Invasive Species Research Center and the Legislative-Citizen Commission on Minnesota Resources, and the State of Minnesota.<br><br>"), 
id = "footerText",
style = "min-width: 320px;"
),


# ARIA LIVE REPORTING REGION ----------------------------------------------

#THIS IS A SHINY LIVE REGION THAT IS NOT VISIBLE TO ANYONE BUT IS SCREEN-READER-ENABLED. WHENEVER WE GENERATE A NOTIFICATION, WE CAN TRIGGER A MESSAGE TO GO INTO THIS REGION, WHERE IT'LL THEN BE READ ALOUD TO SCREEN-READER USERS. SEE SHINYLIVEREPORTINGREGION.JS
tags$div(id = "a11y-live-region", 
         `aria-live` = "assertive", 
         `aria-atomic` = "true", 
         class = "sr-only", 
         style = "position: absolute; width: 1px; height: 1px; margin: -1px; border: 0; padding: 0; overflow: hidden; clip: rect(0 0 0 0);")

) #End UI
