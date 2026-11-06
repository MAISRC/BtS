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
 
# LOAD NECESSARY INPUTS -------------------------------------------
# 
# dows_lakenames_counties = read.csv("inputs/Static/dows_lakenames_counties.csv", 
#                                    colClasses = "character")

## BASIC INPUTS -------------------------------------------

# STATE OUTLINE
MN = readRDS("inputs/Static/MN") 

#DEFINITIVE LIST OF INVASIVES
allInvasivesList = read.csv("inputs/Static/invasives_list_revised_2026.csv")

### LAKES DATABASE -------------------------------------------

# OBJECT CONTAINING LAKE POLYGONS, DOWS, COUNTIES, WB_NAMES, CENTROIDS, AND ACREAGE.
# polys = read_sf("H:\\Shared drives\\MAISRC\\Quantification, Data, and Computation\\Projects\\Hansen lab EWM SDM Project\\Hansen EWM Viz\\data\\dnr_hydro_features_all.shp")
# 
# polys2 = polys %>%
#   filter(!is.na(dowlknum), outside_mn != "Y") %>%
#   rename(DOW = dowlknum) %>%
#   select(DOW, geometry, COUNTY = cty_name, LAKE_NAME = map_label, center_utm, center_u_1, LAKE_SIZE = acres) %>%
#   st_simplify(preserveTopology = TRUE,
#               dTolerance = 50) %>%
#   st_transform(crs = 4326) %>%
#   st_make_valid() #MAKE SURE ALL THE POLYGON EDGES ARE OK AFTER SIMPLIFICATION
# 
# #GET RID OF SUBBASINS
# polys2$DOW[str_sub(polys2$DOW, 7, 8) != "00"] = paste0(str_sub(polys2$DOW[str_sub(polys2$DOW, 7, 8) != "00"], 1, 6), "00")
# 
# #THERE IS ONE ERRANT VALUE IN THE LAKE CENTROID DATA FOR GULL LAKE IN CASS COUNTY.
# polys2$center_utm[polys2$DOW == "11030500"] = 396218 #THIS, FROM CODEX, SHOULD FIX IT.
# 
#SOME DOWS HAVE NO NAMES
# polys2$LAKE_NAME[is.na(polys2$LAKE_NAME)] = "Unnamed"
# 
# saveRDS(polys2, "inputs/Static/allMNlakepolygons.rds")

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
# saveRDS(lakesDBsimple, "inputs/Static/allMNlakecentroids.rds")

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
url = "https://raw.githubusercontent.com/MAISRC/MNDNR_IWL/refs/heads/main/MNDNR_IWF_Transformation.qmd"

#REQUIRES TEMPORARILY WRITING PLAIN VERSIONS OF THE QMD FILE AND THE R CODE IN IT
qmd_file = tempfile(fileext = ".qmd")
r_file = tempfile(fileext = ".R")

download.file(url, destfile = qmd_file, mode = "wb", quiet = TRUE)

# PURL TRANSFERS JUST THE R CODE OVER TO A NEW FILE TO BE SOURCED.
knitr::purl(
  input = qmd_file,
  output = r_file,
  documentation = 0,
  quiet = TRUE
)

#THEN, RUN THAT R CODE TO PRODUCE THE FILE THE APP WANTS.
source(r_file, local = TRUE, echo = FALSE)

IWL = readr::read_csv("infestedWaters_cleanedNInclusive.csv", 
                     col_select = c(DOW, species, year = confirmed_year_inc, connected),
                     col_types = readr::cols( #MORE FORMAL, FOR WHEN WE'RE SELECTING COLUMNS ALSO.
                       DOW = readr::col_character(), #BY BRINGING THIS IN AS CHARACTER, I NO LONGER HAVE TO REPAIR THE DOWS FOR LEADING 0S!
                       species = readr::col_character(),
                       confirmed_year_inc = readr::col_integer(),
                       connected = readr::col_logical()
                     )) %>% 
  dplyr::filter(!is.na(DOW)) %>% #ELIMINATES NON-LAKES.
  dplyr::distinct(DOW, species, connected, year, .keep_all = TRUE) %>%  #ELIMINATE DUPLICATED RECORDS THAT REFLECT SEPARATE SUBBASINS GETTING INFESTED.
  dplyr::group_by(DOW, species, connected) %>% #IF THERE ARE MULTIPLE CONFIRMATIONS (MAYBE DUE TO THINGS LIKE SEPARATE YEARS FOR VELIGERS AND ADULTS), COLLAPSE TO THE FIRST OF THESE.
  dplyr::summarize(year = first(year), .groups = "drop") %>% 
  dplyr::filter(connected == FALSE, .by = c(DOW, species)) #THEN, IF YOU HAVE AN INDEPENDENT CONFIRMATION OF A LAKE PREVIOUSLY LISTED DUE TO CONNECTIONS, KEEP ONLY THE CONFIRMATION VERSION.

invisible(file.remove("infestedWaters_cleanedNInclusive.csv")) #OTHERWISE, THIS LINGERS IN MY ROOT DIRECTORY

#JOIN CENTROID AND LAKE INFO TO IWL
IWL_sf = left_join(IWL, lakesDBsimple, relationship = "many-to-one", by = "DOW") %>% 
  st_as_sf() #MAINTAIN THE SF STATUS

IWL_sf$source = "MN DNR's Infested Waters List"

## CLEANED, CURRENT PI CHARTER GRAB -------------------------------------------

#LOAD IN PI CHARTER SUPPLEMENTAL FOR AQUATIC PLANTS
piCharterSupp = readr::read_csv("inputs/MadeUpstream/PI_Charter_Positives.csv",
                                col_select = c(DOW, species = taxon, year = FIRST_YEAR),
                                col_types = readr::cols( 
                                  DOW = readr::col_character(), 
                                  taxon = readr::col_character(),
                                  FIRST_YEAR = readr::col_integer()
                                ), name_repair = "minimal") %>%  #TO QUIET NEW NAMES WARNINGS.
    dplyr::filter(!is.na(year)) #ONE INSTANCE IS COMING THRU OF A LAKE HAVING CLPW THAT IT DOESN'T ACTUALLY HAVE, ACCORDING TO THE LIVE VERSION OF THE APP...WORTH DOUBLE-CHECKING.

piCharterSupp$species = tolower(piCharterSupp$species) #CASE MATCHING

#TAXON MATCHING
#***LUMPING THE HYBRIDS TOGETHER FOR SIMPLICITY.
piCharterSupp$species[piCharterSupp$species == "hybrid water-milfoil"] = "eurasian water-milfoil" 
piCharterSupp$species[piCharterSupp$species == "hybrid cattail"] = "narrow-leaved cattail" 
piCharterSupp$species[piCharterSupp$species == "curly pondweed"] = "curly-leaf pondweed"
piCharterSupp$species[piCharterSupp$species == "eurasian water-milfoil"] = "Eurasian watermilfoil"

piCharterSupp$source = "P.I. Charter Database"

piCharterSupp_sf = left_join(piCharterSupp, lakesDBsimple, relationship = "many-to-one", by = "DOW")

piCharterSupp_sf$connected = FALSE

IWL_allSources = bind_rows(IWL_sf, piCharterSupp_sf)

## CLEANED NAS DATABASE -------------------------------------------

NAS_sf = readr::read_csv("inputs/Dynamic/NAS-Specimen-Download.csv",  #***ONLY TEMPORARY...
                      col_select = c(species = `Scientific Name`, Latitude, 
                                     Longitude, year = Year, Status),
                      col_types = readr::cols(
                        `Scientific Name` = readr::col_character(),
                        Latitude = readr::col_number(),
                        Longitude = readr::col_number(),
                        Year = readr::col_number(),
                        Status = readr::col_character(),
                       )
                      ) %>% 
  dplyr::filter(!Status %in% c("failed", "extirpated", "eradicated", "stocked"),#***SOMETHING OF A JUDGMENT CALL HERE.
                !is.na(Latitude), !is.na(Longitude), #ONLY ONE OF THESE AT TIME OF WRITING. 
                Longitude >= -97.22904, Longitude <= -89.48923, #ALSO SOME INVALID LAT/LONGS
                Latitude >= 43.49952, Latitude <= 49.38436,
                !species %in% c("Dreissena sp.", "Helisoma sp.")) %>% 
  dplyr::select(-Status) %>%  #DITCH IT NOW.
  sf::st_as_sf(crs = 4326, coords = c("Longitude", "Latitude"))

#ADJUST SOME SPECIES NAMES FOR PROPER JOINING
NAS_sf$species[NAS_sf$species == "Phragmites australis australis"] = "Phragmites australis"
NAS_sf$species[NAS_sf$species == "Eubosmina coregoni"] = "Bosmina coregoni"
NAS_sf$species[NAS_sf$species == "Cipangopaludina japonica"] = "Heterogen japonica"
NAS_sf$species[NAS_sf$species == "Eichhornia crassipes"] = "Pontederia crassipes"
NAS_sf$species[NAS_sf$species == "Myriophyllum × hybridum"] = "Myriophyllum spicatum"
NAS_sf$species[NAS_sf$species == "Ctenopharyngodon idella var. diploid"] = "Ctenopharyngodon idella"
NAS_sf$species[NAS_sf$species == "Typha × glauca"] = "Typha angustifolia" #***SIMPLIFYING

#FIND THE SPECIES THAT OVERLAP W/ OUR INVASIVE SPECIES LIST AND FILTER TO ONLY THOSE
overlaps = intersect(x = NAS_sf$species, allInvasivesList$scientific)
NAS_filtered = NAS_sf %>% 
  filter(species %in% overlaps)

#THEN, CONVERT OVER TO THE STANDARDIZED COMMON NAMES
sci2common = allInvasivesList$common
names(sci2common) = allInvasivesList$scientific
NAS_filtered$species = unname(sci2common[NAS_filtered$species])

stayCapped = c("Chinese mystery snail", "Eurasian or hybrid watermilfoil", "European valve snail", "European water-clover", "Japanese mystery snail", "Java waterdropwort", "Lumholtz's waterflea", "Ponto-Caspian scud", "New Zealand mudsnail", "European valve snail")

NAS_filtered$species[!NAS_filtered$species %in% stayCapped] = tolower(NAS_filtered$species[!NAS_filtered$species %in% stayCapped]) #TURN ALL THESE TO LOWERCASE

NAS_filtered$species[NAS_filtered$species == "New Zealand mudsnail"] = "New Zealand mud snail"
NAS_filtered$species[NAS_filtered$species == "yellow iris"] = "yellow flag"
NAS_filtered$species[NAS_filtered$species == "hybrid cattail"] = "narrow-leaved cattail" #***SIMPLIFYING

#FILTER TO ONLY THOSE OBSERVATIONS THAT TAKE PLACE PLAUSIBLY CLOSE TO A SPECIFIC WATERBODY.
NAS_matches = NAS_filtered[lengths(st_is_within_distance(NAS_filtered, lakesDB, dist = 50)) > 0, ] #50 METERS SEEMS REASONABLY FAIR

#JOIN IN THE LAKE DATABASE DATA TO GET CENTROID, SIZE, COUNTY, ETC. DATA. ***WILL JOIN SOME RECORDS TO MULTIPLE WATERBODIES BY VIRTUE OF PROXIMITY. I HAVE NO REASON TO THINK THAT'S A BAD THING THOUGH.
NAS_joined = st_join(x = NAS_matches, y = lakesDB, 
                     join = st_is_within_distance, dist = 50) %>% 
  st_drop_geometry() %>% #DITCH THE OBSERVATION GEOMETRY.
  st_as_sf(crs = 26915, coords = c("center_utm", "center_u_1")) %>% #CHANGE OVER TO THE LAKE CENTROID GEOMETRY.
  st_transform(crs = 4326) %>% 
  distinct(species, year, DOW, geometry, .keep_all = TRUE) #UNCLEAR TO ME WHY THIS IS NEEDED--PROBABLY HAS T DO WITH THE ST_JOIN INTRODUCING DUPLICATES.

NAS_joined$source = "Nonindigenous Aquatic Species (NAS) Database"
NAS_joined$connected = FALSE

IWL_allSources = bind_rows(IWL_allSources, NAS_joined)

# ### PRE-BAKE GLOBAL ENVIRONMENT OBJECTS ### -----------------------------

#SPECIES TO BE OPTIONALLY EXCLUDED DUE TO RARITY
rares = IWL_allSources %>% 
  group_by(species) %>% 
  summarize(n = n()) %>% 
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


## STARTING DF -------------------------------------------------------------
#EFFECTS OPINIONATED STARTING CONDITIONS SET BY ME
excludeRaresStart = TRUE
startingYear = 1987

startingDF = IWL_allSources %>% 
  dplyr::filter(
    if(excludeRaresStart) { species %in% setdiff(unique(species), rares) } else { TRUE },
    year >= startingYear
    )