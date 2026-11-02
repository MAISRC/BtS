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

IWL = read.csv("inputs/Dynamic/infestedWaters_cleanedNInclusive.csv") %>% 
  filter(!is.na(DOW)) 

IWL$DOW = as.character(IWL$DOW)
IWL$DOW[nchar(IWL$DOW) == 7] = paste0("0", IWL$DOW[nchar(IWL$DOW) == 7])

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

# ### PRE-BAKE GLOBAL ENVIRONMENT OBJECTS ### -----------------------------

spp_pal = viridis(
  n = length(unique(IWL_allSources$species)) + 1,
  option = "viridis"
)

names(spp_pal) = c(unique(IWL_allSources$species), "All")

make_infest_graph = function(currDF) { #CURRDF HERE IS ALREADY SUMMARIZED
  
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
    colors = spp_pal,
    type = "scatter",
    mode = "lines",
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
