#IT'S USEFUL TO WRAP EVERYTHING IN THE UI IN A FLUIDPAGE BECAUSE FLUIDPAGE CAN HANDLE BEING STUFFED FULL OF SHINY ADMINISTRATIVE CODE, WHEREAS OTHER UI ELEMENTS LIKE NAVBARPAGE DOESN'T LIKE THEM. 
ui = fluidPage(
  id = "whole_page",
  
  title = "Browser tab title", #THIS IS THE TEXT THAT'LL GO IN THE BROWSER TAB FOR YOUR USER WHEN YOUR APP IS OPEN.
  
  tags$html(lang = "en"), #SET THE PAGE LANGUAGE TO ENGLISH FOR SCREEN READERS. MUST BE DONE AS "HIGH" IN THE APP STRUCTURE AS POSSIBLE!
  
#   ### LOAD IN OUTSIDE FILES ### -----------------------------------------
  
  #LOAD IN OUR STYLE SHEET.
  tags$head(tags$link(
    rel = "stylesheet", 
    type = "text/css",
    href = "CSSTemplate.css" #OR WHATEVER YOU RENAME THIS FILE TO.
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
     shiny::HTML("Charting your course..."), #Provides more text so that it doesn't need to go into the alt text.
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
    #   img(src = "PIlogocrop.png",
    #       alt = "P.I. Charter.",#THIS ALT SHOULD JUST BE THE TEXT SIGHTED PERSONS WOULD SEE HERE.
    #       style = "min-width: 320px;")
    # ),
), 
    #IF THERE'S A NAV BAR IN THE HEADER, IT SHOULD BEAR THIS SEMANTIC TAG.
    class = "flexthis flexcol width100 justifycenter flexwrap",
    tags$nav( 
                         
      class = "flexthis flexwrap justifycenter",
                     )
                    )
),


## ### MAIN CONTENT/MODULES ### --------------------------------------------

#PUT YOUR APP'S MAIN CONTENT HERE. 
# 
# exampleUI(), #IF YOU HAVE YOUR UI/SERVER FILES MODULARIZED, HERE IS WHERE YOU MIGHT OPEN THE MODULES.

textOutput("sampleText"),


## ### FOOTER ### ----------------------------------------------------------

#Insert a footer with links, contact info, funding credits, and current version number.
tags$footer(
HTML("<br>Created by the Minnesota Aquatic Invasive Species Research Center, University of Minnesota by <address><a href='mailto:bajcz003@umn.edu'>Dr. Alex Bajcz (bajcz003@umn.edu)</a></address>, under the current direction of <address><a href='mailto:walsh229@umn.edu'>XXX (XXX@umn.edu)</a></address>.<br>
App last updated XXX XXX XXX. Version XX.XX.XX. View the <a href = 'XXX' target = '_blank'>accessibility statement</a> (opens in new tab).<br>
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
