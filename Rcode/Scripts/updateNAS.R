library(dplyr)
library(jsonlite)
library(sf)

BtSInvasivesList = read.csv("inputs/Static/invasives_list_revised_2026_v2.csv", encoding = "UTF-8")
lakesDB = readRDS("inputs/Static/allMNlakepolygons.rds")

init = jsonlite::fromJSON(
  "https://nas.er.usgs.gov/api/v2/occurrence/search?state=MN"
)$results %>%
  dplyr::select(species = scientificName,
                latitude = decimalLatitude,
                longitude = decimalLongitude,
                year, 
                status) 

init2 = init %>% 
  dplyr::filter( #REMOVE INVALID COORDS AND VAGUE SPECIES
    !is.na(latitude), !is.na(longitude), 
    longitude >= -97.22904, longitude <= -89.48923,
    latitude >= 43.49952, latitude <= 49.38436,
    !species %in% c("Dreissena sp.", "Helisoma sp.")) %>% 
  sf::st_as_sf(crs = 4326, coords = c("longitude", "latitude"))

#FILTER TO ONLY TAXA WE CONSIDER INVASIVE
overlaps = intersect(x = init2$species, BtSInvasivesList$scientific)

init3 = init2 %>% 
  filter(species %in% overlaps)

#CONVERT TO COMMON NAMES
sci2common = BtSInvasivesList$common
names(sci2common) = BtSInvasivesList$scientific
init3$species = unname(sci2common[init3$species])


#JOIN TO KNOWN WBS BY PROXIMITY, THEN ELIMINATE OBSERVATION GEOMETRY AND REPLACE W/ WB CENTROID GEOMETRY. 
init4 = st_join(x = init3, y = lakesDB, 
                     join = st_is_within_distance, dist = 50) %>% 
  filter(!is.na(DOW)) %>%  #MAKE SURE IT JOINS TO SOMETHING.
  st_drop_geometry() %>% 
  st_as_sf(crs = 26915, coords = c("center_utm", "center_u_1")) %>% 
  st_transform(crs = 4326) %>% 
  arrange(DOW, species, year)

#NOW, FILTER BY STATUSES
init4$status[is.na(init4$status)] = "unknown" #FOR CONSISTENCY
init4$status[init4$status == "locally established"] = "established"

#RULES FOR SUMMARIZING EACH WATERBODY/TAXON HISTORY:
#1. EXCLUDE STOCKED RECORDS AND RECORDS WITHOUT A YEAR.
#2. WITHIN A YEAR, ANY COLLECTED/ESTABLISHED RECORD MAKES THE YEAR POSITIVE.
#   OTHERWISE, ANY FAILED/ERADICATED/EXTIRPATED RECORD MAKES IT NEGATIVE.
#   A YEAR WITH ONLY UNKNOWN RECORDS REMAINS UNKNOWN.
#3. DISCARD THE LAST NEGATIVE YEAR (IF ANY) AND ALL EARLIER YEARS. A RESTART REQUIRES
#   A POSITIVE RECORD AFTER THAT YEAR; SUBSEQUENT UNKNOWNS ALONE DO NOT RESTART IT.
#4. KEEP THE FIRST POSITIVE YEAR IN THE REMAINING HISTORY. UNKNOWN RECORDS
#   BEFORE OR AFTER THAT POSITIVE DO NOT CHANGE ITS YEAR OR TRAJECTORY.
#5. IF THE ENTIRE HISTORY IS UNKNOWN, RETAIN ITS FIRST YEAR AS INCONCLUSIVE.

init5 = init4 %>%
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

init5$source = "Nonindigenous Aquatic Species (NAS) Database"
init5$connected = FALSE
init5$species = tolower(init5$species)

saveRDS(init5, file = "inputs/Dynamic/NAS-current.rds")
