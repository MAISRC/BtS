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
source("Rcode/Scripts/normalizeInvasiveCommonNames.R")

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

#JOIN CENTROID AND LAKE INFO TO IWL
IWL_sf = left_join(IWL, lakesDBsimple, relationship = "many-to-one", by = "DOW") %>% 
  st_as_sf() #MAINTAIN THE SF STATUS

IWL_sf$source = "MN DNR's Infested Waters List"

#***COMBINE RELATED TAXA
IWL_sf$species[IWL_sf$species == "Eurasian watermilfoil"] = "Eurasian or hybrid watermilfoil"

## CLEANED, CURRENT PI CHARTER GRAB -------------------------------------------

#LOAD IN PI CHARTER SUPPLEMENTAL FOR AQUATIC PLANTS
piCharterSupp = readr::read_csv("inputs/MadeUpstream/PI_Charter_Positives.csv",
                                col_select = c(DOW, species = taxon, year = FIRST_YEAR),
                                col_types = readr::cols( 
                                  DOW = readr::col_character(), 
                                  taxon = readr::col_character(),
                                  FIRST_YEAR = readr::col_integer()
                                ), name_repair = "minimal") %>%  #TO QUIET NEW NAMES WARNINGS.
    dplyr::filter(!is.na(year))  #***ONE INSTANCE IS COMING THRU OF A LAKE HAVING CLPW THAT IT DOESN'T ACTUALLY HAVE, ACCORDING TO THE LIVE VERSION OF THE APP...WORTH DOUBLE-CHECKING.
 

piCharterSupp$species = tolower(piCharterSupp$species) #CASE MATCHING

#TAXON MATCHING
#***LUMPING THE HYBRIDS TOGETHER FOR SIMPLICITY.
piCharterSupp$species[piCharterSupp$species %in% c("hybrid water-milfoil", "eurasian water-milfoil", "eurasian or hybrid watermilfoil")] = "Eurasian or hybrid watermilfoil" 
piCharterSupp$species[piCharterSupp$species %in% c("hybrid cattail", "narrow-leaved cattail")] = "narrow-leaved or hybrid cattail" 
piCharterSupp$species[piCharterSupp$species == "curly pondweed"] = "curly-leaf pondweed"
piCharterSupp$species[piCharterSupp$species == "yellow iris"] = "yellow flag"

piCharterSupp$source = "P.I. Charter Database"

#WHEN THE TAXA GET LUMPED, AS ABOVE, IT CREATES THE POSSIBILITY OF FUNCTIONALLY DUPLICATE RECORDS. 

piCharterSupp = piCharterSupp %>% 
  dplyr::filter(year == min(year), .by = c(DOW, species)) %>% 
  distinct(DOW, species, year , .keep_all = TRUE) #THE ABOVE WOULDN'T GET RID OF SAME-YEAR COLLISIONS, SO THIS IS NEEDED TO DO SO.

piCharterSupp_sf = left_join(piCharterSupp, lakesDBsimple, relationship = "many-to-one", by = "DOW")

piCharterSupp_sf$connected = FALSE

IWL_allSources = bind_rows(IWL_sf, piCharterSupp_sf)

## CLEANED NAS DATABASE -------------------------------------------

NAS_sf = readr::read_csv("https://raw.githubusercontent.com/MAISRC/BtS/main/inputs/Dynamic/NAS-current.csv",
                      col_select = c(species, latitude, longitude, year, status),
                      col_types = readr::cols(
                        species = readr::col_character(),
                        latitude = readr::col_number(),
                        longitude = readr::col_number(),
                        year = readr::col_number(),
                        status = readr::col_character(),
                       )
                      ) %>% 
  dplyr::filter(
    #I THINK FILTERING BY STATUS BEFORE WE HAVE A DOW COULD BE PREMATURE.
    #!status %in% c("failed", "extirpated", "eradicated", "stocked"),#***SOMETHING OF A JUDGMENT CALL HERE.
                !is.na(latitude), !is.na(longitude), #ONLY ONE OF THESE AT TIME OF WRITING. 
                longitude >= -97.22904, longitude <= -89.48923, #ALSO SOME INVALID LAT/LONGS
                latitude >= 43.49952, latitude <= 49.38436,
                !species %in% c("Dreissena sp.", "Helisoma sp.")) %>% 
#  dplyr::select(-status) %>%  #DITCH IT NOW.
  sf::st_as_sf(crs = 4326, coords = c("longitude", "latitude"))

#ADJUST SOME SPECIES NAMES FOR PROPER JOINING
NAS_sf$species[NAS_sf$species == "Phragmites australis australis"] = "Phragmites australis"
NAS_sf$species[NAS_sf$species == "Eubosmina coregoni"] = "Bosmina coregoni"
NAS_sf$species[NAS_sf$species == "Cipangopaludina japonica"] = "Heterogen japonica"
NAS_sf$species[NAS_sf$species == "Eichhornia crassipes"] = "Pontederia crassipes"
NAS_sf$species[NAS_sf$species == "Myriophyllum × hybridum"] = "Myriophyllum spicatum"
NAS_sf$species[NAS_sf$species == "Ctenopharyngodon idella var. diploid"] = "Ctenopharyngodon idella"
NAS_sf$species[NAS_sf$species == "Typha × glauca"] = "Typha angustifolia" #***SIMPLIFYING

#HISTORICAL SCIENTIFIC NAMES FOR THE NEW PATHOGENS. NONE APPEAR IN THE CURRENT NAS FILE.
NAS_sf$species[NAS_sf$species == "Myxosoma cerebralis"] = "Myxobolus cerebralis"
NAS_sf$species[NAS_sf$species == "Heterosporis sutherlanda"] = "Heterosporis sutherlandae" #SPELLING USED ON THE MAISRC PAGE
NAS_sf$species[NAS_sf$species %in% c("Piscine novirhabdovirus", "Oncorhynchus 2 novirhabdovirus",
                                  "Viral hemorrhagic septicemia virus")] = "Novirhabdovirus piscine"
NAS_sf$species[NAS_sf$species %in% c("Santee-Cooper ranavirus", "Largemouth bass virus")] = "Ranavirus micropterus1"
NAS_sf$species[NAS_sf$species %in% c("Carp sprivivirus", "Rhabdovirus carpio",
                                  "Spring viremia of carp virus", "Spring viraemia of carp virus")] = "Sprivivirus cyprinus"

#OLDER NAMES USED IN THE MISAC RATINGS AND SPECIES RECORDS.
NAS_sf$species[NAS_sf$species == "Cylindrospermopsis raciborskii"] = "Raphidiopsis raciborskii"
NAS_sf$species[NAS_sf$species %in% c("Cyprinid herpesvirus 3", "Koi herpesvirus")] = "Cyvirus cyprinidallo3"

#FIND THE SPECIES THAT OVERLAP W/ OUR INVASIVE SPECIES LIST AND FILTER TO ONLY THOSE
overlaps = intersect(x = NAS_sf$species, allInvasivesList$scientific)
NAS_filtered = NAS_sf %>% 
  filter(species %in% overlaps)

#THEN, CONVERT OVER TO THE STANDARDIZED COMMON NAMES
sci2common = allInvasivesList$common
names(sci2common) = allInvasivesList$scientific
NAS_filtered$species = unname(sci2common[NAS_filtered$species])

NAS_filtered$species = normalizeInvasiveCommonNames(NAS_filtered$species)

#FILTER TO ONLY THOSE OBSERVATIONS THAT TAKE PLACE PLAUSIBLY CLOSE TO A SPECIFIC WATERBODY.
NAS_matches = NAS_filtered[lengths(st_is_within_distance(NAS_filtered, lakesDB, dist = 50)) > 0, ] #50 METERS SEEMS REASONABLY FAIR

#JOIN IN THE LAKE DATABASE DATA TO GET CENTROID, SIZE, COUNTY, ETC. DATA. ***WILL JOIN SOME RECORDS TO MULTIPLE WATERBODIES BY VIRTUE OF PROXIMITY. I HAVE NO REASON TO THINK THAT'S A BAD THING THOUGH.
NAS_joined = st_join(x = NAS_matches, y = lakesDB, 
                     join = st_is_within_distance, dist = 50) %>% 
  st_drop_geometry() %>% #DITCH THE OBSERVATION GEOMETRY.
  st_as_sf(crs = 26915, coords = c("center_utm", "center_u_1")) %>% #CHANGE OVER TO THE LAKE CENTROID GEOMETRY.
  st_transform(crs = 4326) %>% 
  arrange(DOW, species, year) #SORT SO THAT, BY WB AND SPECIES, ALL OCCURANCES OCCUR IN TEMPORAL ORDER.


#NEXT, WE FILTER BY STATUSES, NOW THAT WE HAVE DOWS. 

#MAKE MORE CONSISTENT FOR MATCHING
NAS_joined$status[is.na(NAS_joined$status)] = "unknown"
NAS_joined$status[NAS_joined$status == "locally established"] = "established"

#RULES FOR SUMMARIZING EACH WATERBODY/TAXON HISTORY:
#1. EXCLUDE STOCKED RECORDS AND RECORDS WITHOUT A YEAR.
#2. WITHIN A YEAR, ANY COLLECTED/ESTABLISHED RECORD MAKES THE YEAR POSITIVE.
#   OTHERWISE, ANY FAILED/ERADICATED/EXTIRPATED RECORD MAKES IT NEGATIVE.
#   A YEAR WITH ONLY UNKNOWN RECORDS REMAINS UNKNOWN.
#3. DISCARD THE LAST NEGATIVE YEAR AND ALL EARLIER YEARS. A RESTART REQUIRES
#   A POSITIVE RECORD AFTER THAT YEAR; SUBSEQUENT UNKNOWNS ALONE DO NOT RESTART IT.
#4. KEEP THE FIRST POSITIVE YEAR IN THE REMAINING HISTORY. UNKNOWN RECORDS
#   BEFORE OR AFTER THAT POSITIVE DO NOT CHANGE ITS YEAR OR TRAJECTORY.
#5. IF THE ENTIRE HISTORY IS UNKNOWN, RETAIN ITS FIRST YEAR AS INCONCLUSIVE.

NAS_joined = NAS_joined %>%
  filter(status != "stocked", !is.na(year)) %>%
  mutate(new_status = case_when(
    status %in% c("collected", "established") ~ "positive",
    status %in% c("failed", "extirpated", "eradicated") ~ "negative",
    TRUE ~ "unknown"
  )) %>%
  mutate(sum_status = case_when(
    any(new_status == "positive") ~ "positive",
    any(new_status == "negative") ~ "negative",
    TRUE ~ "unknown"
  ), .by = c(DOW, species, year)) %>%
  mutate(last_negative = max(year[sum_status == "negative"], -Inf),
         .by = c(DOW, species)) %>%
  filter(year > last_negative) %>%
  mutate(traj = case_when(
    any(sum_status == "positive") ~ "positive",
    is.finite(first(last_negative)) ~ "negative",
    TRUE ~ "unknown"
  ), .by = c(DOW, species)) %>%
  filter(traj != "negative") %>%
  filter(traj == "unknown" | sum_status == "positive") %>%
  filter(year == min(year, Inf), .by = c(DOW, species)) %>%
  distinct(DOW, species, .keep_all = TRUE) %>%
  select(-c(status, new_status, sum_status, last_negative))

NAS_joined$source = "Nonindigenous Aquatic Species (NAS) Database"
NAS_joined$connected = FALSE

IWL_allSources = bind_rows(IWL_allSources, NAS_joined)
IWL_allSources$traj[is.na(IWL_allSources$traj)] = "positive" #JUST TO FILL THIS REMAINING COLUMN FOR THE OTHER TWO SOURCES.

## CLEANED EDDMAPS DATABASE -------------------------------------------
EM_joined = readRDS("inputs/Dynamic/EDDMapS-current.rds")
EM_joined$species = normalizeInvasiveCommonNames(EM_joined$species)

IWL_allSources = bind_rows(IWL_allSources, EM_joined)

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
