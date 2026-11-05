#IT'S USEFUL TO WRAP EVERYTHING IN THE UI IN A FLUIDPAGE BECAUSE FLUIDPAGE CAN HANDLE BEING STUFFED FULL OF SHINY ADMINISTRATIVE CODE, WHEREAS OTHER UI ELEMENTS LIKE NAVBARPAGE DOESN'T LIKE THEM. 
ui = fluidPage(
  id = "whole_page",
  
  title = "Beating the Spread", #THIS IS THE TEXT THAT'LL GO IN THE BROWSER TAB FOR YOUR USER WHEN YOUR APP IS OPEN.
  
  tags$html(lang = "en"), #SET THE PAGE LANGUAGE TO ENGLISH FOR SCREEN READERS. MUST BE DONE AS "HIGH" IN THE APP STRUCTURE AS POSSIBLE!
  
#   ### LOAD IN OUTSIDE FILES ### -----------------------------------------
  
  #LOAD IN OUR STYLE SHEET.
  tags$head(tags$link(
    rel = "stylesheet", 
    type = "text/css",
    href = "BtSCSS.css" #OR WHATEVER YOU RENAME THIS FILE TO.
  ),
  

## ### LOAD IN CONTEXT-DEPENDENT JS SCRIPTS ### ----------------------------

#I'VE FOUND A LOT OF REASONS OVER MY TIME WITH SHINY TO INCORPORATE CUSTOM JS SCRIPTS TO ACCOMPLISH CERTAIN SPECIFIC THINGS. I LOAD THESE HERE (SITUATIONALLY). COMMENT OUT ANY THAT AREN'T RELEVANT.

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

#JS FUNCTION THAT FORCES THE DATE PICKER POPUP THAT COMES ALONG WITH SHINY'S DATE SELECTOR TO BE A BIT ABOVE THE ACCOMPANYING TEXT BOX SO IT DOESN'T COVER UP THE TYPING BOX.
  tags$script(
    src = "js/preventDateInputOverlaps.js"
  ),
# 
# #JS FUNCTION THAT FIXES MULTIPLE ACCESSIBILITY ISSUES WITH DT TABLES.
# tags$head(
#   tags$script(
#     src = "js/improveDTTableA11y.js"
#   )
# ),

# #UPON REFRESH, YOU WON'T AUTOMATICALLY COME BACK TO THE TOP OF THE PAGE. THIS WOULD TRIGGER THAT TO HAPPEN.
# tags$head(
#   tags$script(HTML("
#   $(document).on('shiny:connected', function() {
#       window.scrollTo(0, 0);
#     });
#   "))
# ),

#UPON DISCONNECT, ENSURE THAT FOCUS SHIFTS TO THE CUSTOM DISCONNECT MESSAGE AND THAT TEXT IS INSERTED INTO THE REFRESH LINK.
tags$script(
  src = "js/shiftFocusOnDisconnect.js"
),

#GENERATE A FUNCTION THAT ALLOWS JS AND SHINY TO SEND MESSAGES TO THE ARIA LIVE REPORTING REGION TO BE REPORTED TO SCREEN-READER USERS.
tags$script(
  src = "js/shinyLiveReportingRegion.js"
)
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
          style = "min-width: 320px;"),
      img(src = "beating-the-spread.png",
          alt = "Beating the Spread",#THIS ALT SHOULD JUST BE THE TEXT SIGHTED PERSONS WOULD SEE HERE.
          style = "min-width: 320px;")
    ),
), 
    #IF THERE'S A NAV BAR IN THE HEADER, IT SHOULD BEAR THIS SEMANTIC TAG.
    class = "flexthis flexcol width100 justifycenter flexwrap",
    tags$nav( 
                         
      class = "flexthis flexwrap justifycenter",
   )
),


## ### MAIN CONTENT/MODULES ### --------------------------------------------

tags$main(
  id = "map_main",
  
div(
  id = "infest_map_div",
  h2("Which lakes are invaded with which taxa?"),
  
  tags$figure(
    tags$figcaption("Map showing lakes (points) with confirmed infestations given your current input selections. Hover points for more information. "),
    leafletOutput("infest_map", width = "100%", height = "450px"),
  ),

tags$fieldset(
  tags$legend("Control which infestations are mapped"),
  
  fluidRow(
    style = "width: 100%;",
    
    column(width = 4, offset = 1, 
           
           pickerInput("infest_spp", 
                       label = "Invader(s)",
                       choices = sort(unique(IWL_allSources$species)), 
                       selected = setdiff(unique(IWL_allSources$species), rares),  #ASSUMES EXCLUDES RARES IS CHECKED TO START. 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           
           
           pickerInput("infest_ctys", 
                       label = "County(ies)",
                       choices = sort(unique(IWL_allSources$counties[!grepl(",", IWL_allSources$counties)])), 
                       selected = unique(IWL_allSources$counties[!grepl(",", IWL_allSources$counties)]), 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           ),
           
           pickerInput("infest_source", 
                       label = "Source database(s)",
                       choices = sort(unique(IWL_allSources$source)), 
                       selected = unique(IWL_allSources$source), 
                       multiple = TRUE, 
                       options = pickerOptions(actionsBox = TRUE, 
                                               selectedTextFormat = "count > 2",
                                               countSelectedText = "{0} selected"
                       )
           )
           
    ), #END FIRST COL
    
    column(width = 4, offset = 1, 
  
  sliderInput("infest_years", 
              label = "Year confirmed", 
              min = min(IWL_allSources$confirmed_year_inc, na.rm=T), 
              max = max(IWL_allSources$confirmed_year_inc, na.rm=T), 
              step = 1, 
              value = c(min(IWL_allSources$confirmed_year_inc, na.rm=T), max(IWL_allSources$confirmed_year_inc, na.rm=T)),
              sep = ""
                ),
  
  checkboxInput("exclude_conns", 
                label = "Exclude records listed due to water connections, not independent confirmations (by state statute, waterbodies connected to infested waterbodies are treated as infested, and independent confirmation is rare)", 
                value = FALSE),
  
  checkboxInput("exclude_noaccess", 
                label = "Exclude records from waterbodies without public accesses", 
                value = FALSE),
  
  checkboxInput("exclude_rares",
                label = "Exclude taxa with few (< 8) infestations",
                value = TRUE)

    ) #END SECOND COL
  
  ) #END FLUID ROW
 
  
  )

 ),

hr(),
br(),

div(
  id = "infest_graph_div",
  h2("How have the rates of new infestations changed over time?"),
  tags$figure(
    tags$figcaption("Line graph showing the numbers of new confirmed infestations (#s of waterbodies with DOW numbers; y-axis) per year (x-axis) by invasive species (colors). Lines can be hovered for more information. Double-click a legend key to select just a single line; single-click to remove a line."),
plotlyOutput("infest_graph", width = "100%", height = "500px")
)
),

hr(),
br(),

div(
  id = "saturation_div",
  h2("How \"saturated\" with invaders are Minnesota's lakes?"),
  
  tags$section(
    p("AIS spread prevention can only be effective if there are still invadable waterbodies that haven't yet been invaded and we can thus prevent them from becoming invaded. So, we might wonder: \"How close to fully invaded\" are Minnesota's lakes? Here, we define \"fully invaded\" as every (invadable) lake having every possible invader."),
    p("As such, the answer to this important question depends on three main factors: "),
    tags$ul(
      tags$li("Which waterbodies, regions, and taxa are we considering?"),
      tags$li("What fraction of waterbodies is actually \"invadable?\", and"),
      tags$li("What fraction of all \"true\" invasions is known?")
    ),
    p("We know not all lakes are even inhabitable (or colonizable) by all taxa and that the percentage that is inhabitable probably depends on the taxon. Research (Kanankege",
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
      ")) suggests that the percentage of lakes suitable for zebra mussel, starry stonewort, and Eurasian watermilfoil is likely between 30-70%, for example."
    ),
    p(
      "We also know that AIS surveillance and monitoring only catches so many infestations, especially when they are new and small. Because we can only count infestations we know about, the number of existing-but-unknown infestations is important to estimate. One estimate from neighboring Wisconsin from over a decade ago (Latzka",
      em("et al."),
      "2013 (",
      a("see here",
        href = "https://www.researchgate.net/publication/267290078_How_invaded_are_we_really_Aquatic_invasive_species_occurrence_datasets_under-represent_species_distributions_and_misinform_predictive_models",
        target = "_blank",
        rel = "noopener"
      ),
      ")) suggested we may only know about as few as 25% of all existing infestations, though we'd like to think we know about a far greater percentage than that."
    ),
    p("Lastly, the answer also depends on how what pool of waterbodies and taxa one considers. Do we include only lakes large enough to have motorized boat traffic (research suggests boats are the dominant cause of new infestations)? That have public, motorized boat launches? Do we include only relatively common or high-priority taxa?")
  ),
  fluidRow(
    column(width = 4, offset = 1,
  tags$fieldset(
    tags$legend("Use these additional toggles to set your assumptions about how invadable MN lakes are and how many invasions we know about. Use the selectors earlier in the app to control which taxa, regions, and waterbodies are included."),
    numericInput("habitability_selector",
                 label = "% of lakes habitable", 
                 value = 50, 
                 min = 0, 
                 max = 100, 
                 step = 1
                 ),
    numericInput("known_selector",
                 label = "% of true infestations known", 
                 value = 50, 
                 min = 0, 
                 max = 100, 
                 step = 1
                 )
   )
  ),
  column(width = 4, offset = 1,
    tags$figure(
      tags$figcaption(
        "Text displaying the approximate percentage of Minnesota lakes invaded (# known + unknown invasions per lake and taxon / # lakes * # species)."
      ),
      textOutput("saturation_percentage"),
      textOutput("saturation_context")
    )

  )
 )
),

hr(),
br(), 

div(
  id = "info_area_div",
  downloadLink("invasives_list",
               label = "Download a CSV file of all taxa we're considering invasive")
),

), #END MAIN

## ### FOOTER ### ----------------------------------------------------------

#Insert a footer with links, contact info, funding credits, and current version number.
tags$footer(
HTML("<br>Beating The Spread was created by the Minnesota Aquatic Invasive Species Research Center, University of Minnesota by <address><a href='mailto:bajcz003@umn.edu'>Dr. Alex Bajcz (bajcz003@umn.edu)</a></address>, under the current direction of <address><a href='mailto:XXX@umn.edu'>XXX (XXX@umn.edu)</a></address>.<br>
App last updated Nov. 5 2026. Version 0.0.2. View the <a href = 'XXX' target = '_blank'>accessibility statement</a> (opens in new tab).<br>
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
