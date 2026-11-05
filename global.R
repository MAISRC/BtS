# ### LOADING LIBRARIES ### -----------------------------------------------

#BECAUSE EVERY PACKAGE USED MUST BE INSTALLED ON THE INSTANCE WITH EVERY DEPLOYMENT, WE WANT TO MINIMIZE THE NUMBER OF PACKAGES USED IN TOTAL. HERE ARE THE ONES I GENERALLY CONSIDER TO BE ESSENTIAL. DELETE ANY NOT NEEDED. ADD ANY THAT ARE ESSENTIAL IN YOUR CONTEXT.

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

# library(gargle) #GOOGLE DRIVE AUTHETICATION.
# library(googledrive) #GOOGLE DRIVE INTERACTIONS.
# library(googlesheets4) #GOOGLE SHEETS INTERACTIONS.
# library(DT) #DT TABLES

# ### SETTING GLOBAL OPTIONS ### ------------------------------------------

#IN GENERAL, I DON'T DO MUCH HERE, BUT I DO SET UP CONNECTIONS TO GOOGLE DRIVE HERE AS NEEDED. REMOVE THESE IF THEY ARE IRRELEVANT TO YOU.

#SET SCOPES FOR WHAT OUR GOOGLE APIS WILL BE ALLOWED TO DO
# sheets_scope <- "https://www.googleapis.com/auth/spreadsheets"
# drive_scope <- "https://www.googleapis.com/auth/drive"

#SET FILE PATH TO THE GOOGLE SERVICE ACCOUNT TOKEN
# sa_key_path <- "tokens/.secrets/token_name.json"

#DON'T TRY TO AUTHENTICATE USING STANDARD TOKENS.
# options(
#   gargle_oauth_cache = FALSE
#   )

#AUTHENTICATE USING OUR JSON TOKEN ATTACHED TO OUR GOOGLE SERVICE ACCOUNT W/ PROPER SCOPES
# drive_auth(path = sa_key_path, scopes = c(sheets_scope, drive_scope))

#ALSO AUTHENTICATE TO GOOGLE SHEETS SPECIFICALLY
# googlesheets4::gs4_auth(path = sa_key_path, scopes = c(sheets_scope, drive_scope))


# ### LOAD MODULES ### ----------------------------------------------------

#  ### ESTABLISH CONVENIENCE FUNCTIONS ### --------------------------------

source("Rcode/Scripts/shinyConvenienceFunctions.R")
 

# ### LOAD NECESSARY INPUTS ### -------------------------------------------
dows_lakenames_counties = read.csv("inputs/Static/dows_lakenames_counties.csv", colClasses = "character")

#AN OUTLINE OF THE STATE OF MINNESOTA FOR MAPS.
MN = readRDS("inputs/Static/MN") 

#DEFINITIVE LIST OF INVASIVES
allInvasivesList = read.csv("inputs/Static/invasives_list_revised_2026.csv")


# polys = read_sf("H:\\Shared drives\\MAISRC\\Quantification, Data, and Computation\\Projects\\Hansen lab EWM SDM Project\\Hansen EWM Viz\\data\\dnr_hydro_features_all.shp")
# 
# polys = polys %>%
#   filter(!is.na(dowlknum), outside_mn != "Y") %>%
#   rename(DOW = dowlknum) %>%
#   select(DOW, geometry, counties = cty_name, wb_name = map_label, center_utm, center_u_1) %>%
#   st_simplify(preserveTopology = TRUE,
#               dTolerance = 50) %>%
#   st_transform(crs = 4326)
# 
# saveRDS(polys, "inputs/Static/allMNlakepolygons.rds")

polys = readRDS("inputs/Static/allMNlakepolygons.rds")



##GRAB AND RUN THE LATEST VERSION OF THE MNDNR IWL CLEANING CODE FROM MY GITHUB
url = "https://raw.githubusercontent.com/MAISRC/MNDNR_IWL/refs/heads/main/MNDNR_IWF_Transformation.qmd"

#REQUIRES TEMPORARILY WRITING PLAIN VERSIONS OF THE QMD FILE AND THE R CODE IN IT
qmd_file = tempfile(fileext = ".qmd")
r_file = tempfile(fileext = ".R")

download.file(url, destfile = qmd_file, mode = "wb")

# PURL TRANSFERS JUST THE R CODE OVER TO A NEW FILE TO BE SOURCED.
knitr::purl(
  input = qmd_file,
  output = r_file,
  documentation = 0,
  quiet = TRUE
)

#THEN, RUN THAT R CODE TO PRODUCE THE FILE THE APP WANTS.
source(r_file, local = TRUE)

IWL = read.csv("infestedWaters_cleanedNInclusive.csv") %>% 
  filter(!is.na(DOW)) 

IWL$DOW = as.character(IWL$DOW)
IWL$DOW[nchar(IWL$DOW) == 7] = paste0("0", IWL$DOW[nchar(IWL$DOW) == 7])

#****SWAP TO USING THE ALL-ENCOMPASSING POLYS OBJ ABOVE.
wb_polys_all = readRDS("inputs/Static/LAKE_POLY") %>% 
  rename(DOW = dowlknum) 

wb_polys = wb_polys_all %>% 
  select(DOW, center_utm, center_u_1) %>% 
  distinct(DOW, .keep_all = T)

wb_polys$DOW = as.character(wb_polys$DOW)
wb_polys$DOW[nchar(wb_polys$DOW) == 7] = paste0("0", wb_polys$DOW[nchar(wb_polys$DOW) == 7])

wb_polys$DOW = paste0(str_sub(wb_polys$DOW, 1, 6), "00") 
IWL$DOW = paste0(str_sub(IWL$DOW, 1, 6), "00") 

wb_polys = wb_polys %>% 
  distinct(DOW, .keep_all = T)

IWL_sf = left_join(IWL, wb_polys, relationship = "many-to-one")
IWL_sf = st_as_sf(IWL_sf, crs = 26915, coords = c("center_utm", "center_u_1"))
IWL_sf = st_transform(IWL_sf, crs = 4326)
IWL_sf$longs = st_coordinates(IWL_sf)[,1]

IWL_sf = IWL_sf %>% 
  filter(longs < -50)

#SOME OF THESE DIDN'T GET COUNTY INFO FOR SOME REASON
IWL_sf$counties[IWL_sf$DOW == "27000300"] = "Hennepin"
IWL_sf$counties[IWL_sf$DOW == "19000500"] = "Dakota"
IWL_sf$counties[IWL_sf$DOW == "25001700"] = "Goodhue"
IWL_sf$counties[IWL_sf$DOW == "79000500"] = "Wabasha"
IWL_sf$counties[IWL_sf$DOW == "79000100"] = "Wabasha"
IWL_sf$counties[IWL_sf$DOW == "85001300"] = "Winona"
IWL_sf$counties[IWL_sf$DOW == "85000200"] = "Winona"
IWL_sf$counties[IWL_sf$DOW == "85000100"] = "Winona"
IWL_sf$counties[IWL_sf$DOW == "28000500"] = "Houston"
IWL_sf$counties[IWL_sf$DOW == "28000100"] = "Houston"

#AT THIS POINT, PROBABLY DUE TO SUBBASIN COLLAPSING, THERE ARE SOME DUPES WE CAN REMOVE.
IWL_sf = IWL_sf %>% 
  group_by(DOW, species) %>% 
  distinct(DOW, species, .keep_all = TRUE)

IWL_sf$source = "MN DNR's Infested Waters List"

#LOAD IN PI CHARTER SUPPLEMENTAL FOR AQUATIC PLANTS
piCharterSupp = read.csv("inputs/MadeUpstream/PI_Charter_Positives.csv") %>% 
  select(-X)

piCharterSupp$DOW = as.character(piCharterSupp$DOW)
piCharterSupp$DOW[nchar(piCharterSupp$DOW) == 7] = paste0("0", piCharterSupp$DOW[nchar(piCharterSupp$DOW) == 7])

piCharterSupp$taxon = tolower(piCharterSupp$taxon)

piCharterSupp$taxon[piCharterSupp$taxon == "hybrid water-milfoil"] = "eurasian water-milfoil" #***LUMPING THE HYBRIDS TOGETHER FOR SIMPLICITY.
piCharterSupp$taxon[piCharterSupp$taxon == "hybrid cattail"] = "narrow-leaved cattail" 

piCharterSupp = piCharterSupp %>% 
  group_by(DOW, taxon) %>% 
  suppressWarnings(summarize(FIRST_YEAR = first(year(as_date(SURVEY_START))),
                             .groups = "drop_last")) %>% 
  ungroup()

piCharterSupp$taxon[piCharterSupp$taxon == "curly pondweed"] = "curly-leaf pondweed"
piCharterSupp$taxon[piCharterSupp$taxon == "eurasian water-milfoil"] = "Eurasian watermilfoil"

piCharterSupp$source = "P.I. Charter Database"

wb_polys_all = wb_polys_all %>% 
  distinct(DOW, .keep_all = T)

piCharterSupp_sf = left_join(piCharterSupp, wb_polys_all, relationship = "many-to-one")
piCharterSupp_sf$center_u_1[piCharterSupp_sf$DOW == "19000500"] = 4964066 #STUPID LOCK AND DAM POOL 2 IS SCREWING ME OVER.
piCharterSupp_sf$center_utm[piCharterSupp_sf$DOW == "19000500"] = 500000

piCharterSupp_sf = st_as_sf(piCharterSupp_sf, crs = 26915, coords = c("center_utm", "center_u_1"))
piCharterSupp_sf = st_transform(piCharterSupp_sf, crs = 4326)

piCharterSupp_sf = piCharterSupp_sf %>% 
  rename(confirmed_year_inc = FIRST_YEAR,
         species = taxon,
         wb_name = map_label,
         counties = cty_name)

#AT THIS POINT, PROBABLY DUE TO SUBBASIN COLLAPSING, THERE ARE SOME DUPES WE CAN REMOVE.
piCharterSupp_sf = piCharterSupp_sf %>% 
  group_by(DOW, species) %>% 
  distinct(DOW, species, .keep_all = TRUE)

piCharterSupp_sf$connected = FALSE

IWL_allSources = bind_rows(IWL_sf, piCharterSupp_sf)



#MN PUBLIC ACCESS LOCATIONS
# pub_accesses = read_sf("upstream/UpstreamInputs/shor_waspt3.shp") %>%
#   st_drop_geometry() %>%
#   select(DOW = DOWLKNUM) %>%
#   filter(!is.na(DOW))
# 
# saveRDS(pub_accesses, "inputs/Static/pub_accesses.rds")

pub_accesses = readRDS("inputs/Static/pub_accesses.rds")

pub_accesses$DOW = paste0(str_sub(pub_accesses$DOW, 1, 6), "00")

pub_accesses = pub_accesses %>% 
  distinct(DOW) %>%  
  pull()


NAS = read.csv("C:\\Users\\Bajcz\\Downloads\\NAS-Data-Download-11-05-2026-23727\\NAS-Specimen-Download.csv")

overlaps = intersect(x = NAS$Scientific.Name, allInvasivesList$scientific)

NAS_filtered = NAS %>% 
  filter(Scientific.Name %in% overlaps) %>% 
  filter(!is.na(Latitude), !is.na(Longitude), Latitude >= 43, Latitude <= 49, Longitude <= -89, Longitude >= -97)

NAS_sf = st_as_sf(NAS_filtered, crs = 4326, coords = c("Longitude", "Latitude"))


NAS_matches = NAS_sf[lengths(st_intersects(NAS_sf, polys)) > 0, ]

NAS_joined = st_join(NAS_matches, polys)

NAS_svelte = NAS_joined %>% 
  select(Scientific.Name, DOW, geometry, confirmed_year_inc = Date.1, wb_name, counties, center_utm, center_u_1) %>% 
  st_drop_geometry() %>% 
  mutate(DOW = paste0(str_sub(DOW, 1, 6), "00")) %>% 
  distinct(Scientific.Name, DOW, confirmed_year_inc, center_utm, center_u_1) %>% 
  filter(!is.na(confirmed_year_inc))

NAS_svelte$source = "Nonindigenous Aquatic Species (NAS) Database"
NAS_svelte$connected = FALSE

sci2common = allInvasivesList$common
names(sci2common) = allInvasivesList$scientific
NAS_svelte$species = sci2common[NAS_svelte$Scientific.Name]
NAS_svelte$Scientific.Name = NULL
NAS_svelte$species[!NAS_svelte$species %in% c("Chinese mystery snail", "Eurasian watermilfoil","New Zealand mudsnail", "European valve snail")] = tolower(NAS_svelte$species[!NAS_svelte$species %in% c("Chinese mystery snail", "Eurasian watermilfoil","New Zealand mudsnail", "European valve snail")])
NAS_svelte$species[NAS_svelte$species == "New Zealand mudsnail"] = "New Zealand mud snail"
NAS_svelte$species[NAS_svelte$species == "yellow iris"] = "yellow flag"
NAS_svelte$species[NAS_svelte$species == "hybrid cattail"] = "narrow-leaved cattail" #***CONTROVERSIAL

NAS_svelte$DOW = as.character(NAS_svelte$DOW)

NAS_sf_new = st_as_sf(NAS_svelte, crs = 26915, coords = c("center_utm", "center_u_1")) 
NAS_sf_new = st_transform(NAS_sf_new, crs = 4326)

IWL_allSources = bind_rows(IWL_allSources, NAS_sf_new) %>% 
  select(-wb_location_details, -DOW_withSubbasin, -year_listed, confirmed_year_basis, year_or_connected_wb, -confirmed_year, -longs)

# ### PRE-BAKE GLOBAL ENVIRONMENT OBJECTS ### -----------------------------

rares = IWL_allSources %>% 
  group_by(species) %>% 
  summarize(n = n()) %>% 
  filter(n < 8) %>% 
  pull(species)

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

make_infest_graph = function(currDF, pal2use) { #CURRDF HERE IS ALREADY SUMMARIZED

  currDF = dplyr::ungroup(currDF)
  currDF = dplyr::arrange(currDF, species, confirmed_year_inc)
  
  currDF$tooltip_text = paste0(
    "Year: ", currDF$confirmed_year_inc, "<br>",
    "Taxon: ", currDF$species, "<br>",
    "# new infestations: ", currDF$n
  )
  

  
  plot_ly(
    data = currDF,
    y = ~n,
    x = ~confirmed_year_inc,
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
