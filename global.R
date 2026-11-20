# LOADING LIBRARIES -----------------------------------------------

library(shiny) #ESSENTIAL.
library(dplyr) #DATA MANIPULATION.
library(stringr) #STRING MANIPULATION.
library(shinyjs) #COMMON JAVASCRIPT OPERATIONS.
library(waiter) #WAITERS, SPINNERS, AND PRELOADERS.
library(shinydisconnect) #CUSTOM DISCONNECT SCREEN.
library(viridis) #COLORBLIND-FRIENDLY PALETTES
library(shinyWidgets) #FOR IMPROVED INPUTS. 
library(plotly) #PLOTLY GRAPHS
library(sf) #WORKING W/ SPATIAL DATA FOR MAPS (IF USING LEAFLET)
library(leaflet) #LEAFLET MAPS
library(lubridate) #WORKING WITH DATES
library(httr) #THESE FOUR, FOR READING IN AND PROCESSING THE IWL.
library(readr)
library(readxl)
library(knitr)
library(htmlwidgets) #FOR SAVEWIDGET

# GLOBAL OPTIONS ------------------------------------------

# LOAD MODULES ----------------------------------------------------

# CONVENIENCE FUNCTIONS --------------------------------

source("Rcode/Scripts/shinyConvenienceFunctions.R")

make_infest_graph = function(currDF, pal2use) { #CURRDF HERE IS ALREADY SUMMARIZED
  
  currDF = dplyr::ungroup(currDF)
  currDF = dplyr::arrange(currDF, species, year)
  
  currDF$tooltip_text = paste0(
    "Year: ", currDF$year, "<br>",
    "Taxon: ", currDF$species, "<br>",
    "# new infestations: ", currDF$n
  )

  plot_ly(
    data = currDF,
    y = ~n,
    x = ~year,
    color = ~species,
    colors = pal2use,
    name = ~stringr::str_to_sentence(as.character(species)),
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
           yaxis = list(title = "New confirmed infestations", 
                        linecolor = "black", 
                        linewidth = 2, 
                        tickfont = list(family = "Open Sans", color='black', size = 14),
                        fixedrange = TRUE
           ))

}

make_tooltip = function(tooltipText, 
                        tooltipIcon = "question-circle", 
                        pos = "auto", 
                        tooltipLabel = "") {
  
  tags$p(
    class = "inline-tooltips",
    tooltipLabel,
    tags$span(
      icon(tooltipIcon),
      tabindex = "0",
      role = "button",
      `aria-label` = if(nzchar(tooltipLabel)) tooltipLabel else "More information",
      `data-toggle` = "popover",
      `data-trigger` = "click",
      `data-html` = "true",
      onclick = "event.preventDefault()",
      onkeydown = "if(event.key === 'Enter' || event.key === ' ') { event.preventDefault(); this.click(); }",
      `data-placement` = pos, # options: top, bottom, left, right, auto
      `data-content` = as.character(tooltipText)
    )
  )
  
}
 

# FUNCTION FROM CODEX THAT CREATES THE FORMULA SHOWN IN THE TOOLTIP FOR THE SATURATION CALCULATION.
make_saturation_caption = function(byArea = FALSE) {
  tags$figcaption(
    if(byArea) "Approx. % of MN waterbody area invaded." else "Approx. % of MN waterbodies invaded.",
    make_tooltip(
      tooltipText = tagList(
        tags$p("Estimated invasion saturation (%):"),
        if(byArea) {
          tags$p("\\[\\widehat{S}_A = 100 \\times \\frac{I_A / p_d}{A \\, T \\, p_h}\\]")
        } else {
          tags$p("\\[\\widehat{S} = 100 \\times \\frac{I / p_d}{W \\, T \\, p_h}\\]")
        },
        tags$ul(
          tags$li(tags$strong(if(byArea) "\\(I_A\\): " else "\\(I\\): "),
                  if(byArea) "Total areas of waterbodies with documented invasions, each multiplied by the number of invaders documented." else "Numbers of waterbodies with documented invasions multipled by the number of invaders documented at each."),
          tags$li(tags$strong(if(byArea) "\\(A\\): " else "\\(W\\): "),
                  if(byArea) "Total area of all waterbodies that meet your selections." else "Total number of waterbodies that meet your selections."),
          tags$li(tags$strong("\\(T\\): "), "Total number of invaders that meet your selections."),
          tags$li(tags$strong("\\(p_d\\): "), "Fraction of true infestations that have been successfully documented (your percentage divided by 100)."),
          tags$li(tags$strong("\\(p_h\\): "), "Fraction of lakes/lake area actually inhabitable (your percentage divided by 100).")
        ),
        if(byArea) tags$p("Note: Lake Superior is excluded from both area totals due to its disproportionate size.")
      )
    )
  )
}

# LOAD NECESSARY INPUTS -------------------------------------------

## BASIC INPUTS -------------------------------------------

# STATE OUTLINE
MN = readRDS("inputs/Static/MN") 

#DEFINITIVE LIST OF INVASIVES
allInvasivesList = read.csv("inputs/Static/invasives_list_revised_2026_v2.csv")

### LAKES DATABASE -------------------------------------------

# OBJECT CONTAINING LAKE POLYGONS, DOWS, COUNTIES, WB_NAMES, CENTROIDS, AND ACREAGE.
# polys = read_sf("H:\\Shared drives\\MAISRC\\Quantification, Data, and Computation\\Projects\\Hansen lab EWM SDM Project\\Hansen EWM Viz\\data\\dnr_hydro_features_all.shp")


#I CHOSE TO BE PRETTY LOOSE IN MY KEEPING OF SELECT WATERBODY TYPES SO THAT WE INCLUDE THINGS WITH A MORE TERRESTRIAL BENT AND ALSO SO THAT THE USER CAN BE THE ONE TO DETERMINE HOW THEY WANT TO FILTER THESE BY, IF AT ALL. 
# polys2 = polys %>%
#   filter(!is.na(dowlknum), outside_mn != "Y") %>% #IRRELEVANT FOR OUR PURPOSES
#   rename(DOW = dowlknum) %>%
#   filter(wb_class %in% c("Lake or Pond", "Wetland", "Intermittent Water", "Riverine polygon", "Reservoir",   "Artificial Basin")) %>% 
#   select(DOW, geometry, COUNTY = cty_name, LAKE_NAME = map_label, center_utm, center_u_1, LAKE_SIZE = acres, wb_class) %>%
#   st_simplify(preserveTopology = TRUE,
#               dTolerance = 50) %>%
#   st_transform(crs = 4326) %>%
#   st_make_valid() #MAKE SURE ALL THE POLYGON EDGES ARE OK AFTER SIMPLIFICATION
# 
# # #GET RID OF SUBBASINS
# polys2$DOW[str_sub(polys2$DOW, 7, 8) != "00"] = paste0(str_sub(polys2$DOW[str_sub(polys2$DOW, 7, 8) != "00"], 1, 6), "00")
# 
# #THERE IS ONE ERRANT VALUE IN THE LAKE CENTROID DATA FOR GULL LAKE IN CASS COUNTY.
# polys2$center_utm[polys2$DOW == "11030500"] = 396218 #THIS, FROM CODEX, SHOULD FIX IT.
# 
# #SOME DOWS HAVE NO NAMES
# polys2$LAKE_NAME[is.na(polys2$LAKE_NAME)] = "Unnamed"
# 
# 
# #NOW, COLLAPSE TO LARGEST POLYGON FOR EACH DOW SO AS TO NOT GET DUPLICATES.
# polys3 = polys2 %>%
#   filter(LAKE_SIZE == max(LAKE_SIZE), .by = "DOW") %>%
#   distinct(DOW, .keep_all = TRUE) #THE ABOVE DOESN'T QUITE ELIMINATE EVERY DUPE, SO THIS CLEANS UP THE REST.

# saveRDS(polys3, "inputs/Static/allMNlakepolygons.rds")

#MORE COMPLEX VERSION FOR JOINING IN NON-MN DATABASES
lakesDB = readRDS("inputs/Static/allMNlakepolygons.rds")

#A SIMPLER VERSION FOR IWL AND PI CHARTER JOINING THAT DOESN'T HAVE POLYGON GEOMETRIES OR DUPLICATE DOWS, HAS NO ERRANT CENTROID DATA, AND HAS CENTROID GEOMETRIES.

# lakesDBsimple = lakesDB %>%
#   st_drop_geometry() %>%
#   distinct(DOW, .keep_all = TRUE)
# 
# lakesDBsimple = st_as_sf(lakesDBsimple, crs = 26915, coords = c("center_utm", "center_u_1"))
# lakesDBsimple = st_transform(lakesDBsimple, crs = 4326)
# 
#  saveRDS(lakesDBsimple, "inputs/Static/allMNlakecentroids.rds")

lakesDBsimple = readRDS("inputs/Static/allMNlakecentroids.rds")

### LAKES W/ PUBLIC ACCESSES -------------------------------------------

# pub_accesses = read_sf("upstream/UpstreamInputs/shor_waspt3.shp") %>%
#   st_drop_geometry() %>%
#   select(DOW = DOWLKNUM) %>%
#   filter(!is.na(DOW))
# 
# pub_accesses$DOW = paste0(str_sub(pub_accesses$DOW, 1, 6), "00") #ELIMINATE SUBBASINS
# 
# pub_accesses = pub_accesses %>% 
#   distinct(DOW) %>% #ELIMINATE DUPLICATES
#   pull()
# 
# saveRDS(pub_accesses, "inputs/Static/pub_accesses.rds")

pub_accesses = readRDS("inputs/Static/pub_accesses.rds")

## CLEANED, CURRENT IWL -------------------------------------------

#RUN LATEST VERSION OF MNDNR IWL CLEANING CODE FROM MY GITHUB
suppressWarnings(knitr::purl("Rcode/Markdown/MNDNR_IWF_Transformation.qmd", 
                             output = "temp_script.R"))

source("temp_script.R", local = TRUE)

unlink("temp_script.R")

IWL = infestedWaters %>% 
  dplyr::select(DOW, species, connected, year = confirmed_year_inc) %>% 
  dplyr::filter(!is.na(DOW)) %>% #ELIMINATES NON-LAKES.
  dplyr::distinct(DOW, species, connected, year, .keep_all = TRUE) %>%  #ELIMINATE DUPLICATED RECORDS THAT REFLECT SEPARATE SUBBASINS GETTING INFESTED.
  dplyr::group_by(DOW, species, connected) %>% #IF THERE ARE MULTIPLE CONFIRMATIONS (MAYBE DUE TO THINGS LIKE SEPARATE YEARS FOR VELIGERS AND ADULTS), COLLAPSE TO THE FIRST OF THESE.
  dplyr::summarize(year = min(year), .groups = "drop") %>% 
  dplyr::mutate(nRecs = n(), .by = c(DOW, species)) %>% #THEN, IF YOU HAVE AN INDEPENDENT CONFIRMATION OF A LAKE PREVIOUSLY LISTED DUE TO CONNECTIONS, KEEP ONLY THE CONFIRMATION VERSION.
  dplyr::filter(nRecs == 1 | (nRecs == 2 & connected == FALSE)) %>% 
  dplyr::select(-nRecs)

#MATCH THE DNR'S VHS ABBREVIATION TO THE COMMON NAME USED BY THE SPECIES LIST AND NAS.
IWL$species[IWL$species == "VHS"] = "viral hemorrhagic septicemia virus"
IWL$species[IWL$species == "New Zealand mud snail"] = "new zealand mudsnail"

#JOIN CENTROID AND LAKE INFO TO IWL
IWL_sf = left_join(IWL, lakesDBsimple, relationship = "many-to-one", by = "DOW") %>% 
  st_as_sf() #MAINTAIN THE SF STATUS

IWL_sf$source = "MN DNR's Infested Waters List"

#***COMBINE RELATED TAXA
IWL_sf$species[IWL_sf$species == "Eurasian watermilfoil"] = "eurasian or hybrid watermilfoil"
IWL_sf$species = tolower(IWL_sf$species)

## CLEANED, CURRENT PI CHARTER GRAB -------------------------------------------

#LOAD IN PI CHARTER SUPPLEMENTAL FOR AQUATIC PLANTS
piCharterSupp_sf = readRDS("inputs/Dynamic/PI_Charter-current.rds")

IWL_allSources = bind_rows(IWL_sf, piCharterSupp_sf)

## CLEANED NAS DATABASE -------------------------------------------
NAS_file = tempfile(fileext = ".rds")

download.file(
  "https://raw.githubusercontent.com/MAISRC/BtS/main/inputs/Dynamic/NAS-current.rds",
  destfile = NAS_file,
  mode = "wb"
)

NAS_current = readRDS(NAS_file)

unlink(NAS_file)
IWL_allSources = bind_rows(IWL_allSources, NAS_current)

## CLEANED EDDMAPS DATABASE -------------------------------------------
EM_file = tempfile(fileext = ".rds")

download.file(
  "https://raw.githubusercontent.com/MAISRC/BtS/main/inputs/Dynamic/EDDMapS-current.rds",
  destfile = EM_file,
  mode = "wb"
)

EM_current = readRDS(EM_file)

unlink(EM_file)
IWL_allSources = bind_rows(IWL_allSources, EM_current)

IWL_allSources$traj[is.na(IWL_allSources$traj)] = "positive" #JUST TO FILL THIS REMAINING COLUMN FOR THE OTHER TWO SOURCES.

# PRE-BAKE GLOBAL OBJECTS -----------------------------

#SPECIES TO BE OPTIONALLY EXCLUDED DUE TO RARITY
rares = IWL_allSources %>% 
  st_drop_geometry() %>% 
  distinct(DOW, species, .keep_all = TRUE) %>%  #YOU JUST NEED ONE SPECIES/DOW PAIRING FOR THIS, IRRESPECTIVE OF YEAR.
  summarize(n = n(), .by = species) %>% 
  filter(n < 10) %>% 
  pull(species) %>% 
  unname() #***UNCLEAR WHY THESE ARE NAMED

#COLOR PALETTES FOR THE NEW INFESTATIONS OVER TIME GRAPH
spp_pal_all = viridis(
  n = length(unique(IWL_allSources$species)) + 1,
  option = "viridis"
)

names(spp_pal_all) = c(unique(IWL_allSources$species), "All")

spp_pal_one = viridis(
  n = length(unique(IWL_allSources$species)),
  option = "viridis"
)

names(spp_pal_one) = unique(IWL_allSources$species)

#STARTING SPECIES CHOICES
taxa2pick = sort(unique(IWL_allSources$species))
names(taxa2pick) = stringr::str_to_sentence(taxa2pick) #NICER NAMES

## STARTING DF -------------------------------------------------------------
#EFFECTS OPINIONATED STARTING CONDITIONS SET BY ME
excludeRaresStart = TRUE
excludeSmallStart = TRUE
excludeLastUnknowns = TRUE
startingYear = 1987
startingKnown = 50
startingHabitability = 50
startingCounties = sort(unique(IWL_allSources$COUNTY))
startingWBTypes = c("Lake or Pond", "Reservoir", "Riverine polygon", "Wetland")

startingDF = IWL_allSources %>% 
  dplyr::filter(
    if(excludeRaresStart) { species %in% setdiff(unique(species), rares) } else { TRUE },
    if(excludeLastUnknowns) { traj != "unknown" } else { TRUE },
    if(excludeSmallStart) { LAKE_SIZE >= 10 } else { TRUE },
    wb_class %in% startingWBTypes
)
