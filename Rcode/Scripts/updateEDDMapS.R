library(jsonlite) #TO GRAB THE DATA FROM EDDMAPS AS JSON
library(tidyverse)
library(lubridate)
library(sf)

taxonCodes = read.csv("upstream/Admin/EDDMapS/reference/EDDMapS-taxon-queries.csv") #PULL CODEX'S ASSEMBLED LIST OF SPECIES CODES AND CORRESPONDING NAMES FOR OUR INVASIVE SPECIES IN THE EDDMAPS DATABASE.

#SHORTCUTS
speciesCodes = taxonCodes$eddmaps_subject_id
acceptedSpecies = taxonCodes$eddmaps_name

allDat = data.frame() #PRE-ALLOCATED OUTPUT
t1 = Sys.time()

#LOOP THRU SPECIES
for(sp in speciesCodes) {
  
  morePages = TRUE
  page = 1 #START ON PAGE 1
  print(paste0("Now on species: ", sp))
  
  while(morePages == TRUE) {
    
    speciesCode = sp
    
    #PULL NEXT (UP TO) 1K RECORDS FOR THIS SPECIES FROM MINNESOTA
    url = paste0(
      "https://api.bugwoodcloud.org/v2/occurrence?state=27&pagesize=1000&subjectid=",
      speciesCode,
      "&page=",
      page
    )
    
    nextDat = fromJSON(url) #CONVERT FROM JSON TO CSV.
    if(length(nextDat) == 0) {break} #BAIL IF NO RECORDS PULLED.
    
    #SOME NOTES ON COLUMNS EDDMAPS REPORTS:
    #INFESTED AREA AND ABUNDANCE ARE PROBABLY UNRELIABLE AS THEY CAN PERSIST EVEN ONTO ABSENCE RECORDS AND ARE OFTEN NOT POPULATED
    #MANAGEMENT STATUS IS USUALLY EMPTY BUT SOMETIMES CONTAINS VALUES LIKE NOT FOUND, POSSIBLY ERADICATED, AND ERADICATED.
    #VERIFICATION METHOD IS ONLY EVER GOING TO CONTAIN MORE NUANCED POSITIVE INFORMATION AND ISN'T REALLY A GOOD DIVIDING LINE
    
    
    datTidy = nextDat %>% 
      select(scientificname, location, coordinates, identificationcredibility, reviewed, infestationstatus, observationdate, managementstatus, subjectnumber) %>% #USEFUL COLUMNS
      mutate(lat = as.numeric(stringr::str_split_i(coordinates, ", ", i = 1)), #CONVERT COORDINATES --> LAT/LONG
             long = as.numeric(stringr::str_split_i(coordinates, ", ", i = 2)),
             year = year(suppressWarnings(as_date(observationdate)))) %>% #PULL JUST YEAR FROM OBSERVATION DATE
      filter(grepl("Minnesota", location), #MUST BE IN MN, USA (STATE CODE 27 IS NON EXCLUSIVE)
             grepl("United States", location),
             scientificname %in% acceptedSpecies, #MUST BE A SPECIES IN OUR LIST (JUST IN CASE OF BLEED)
             subjectnumber %in% speciesCodes,
             !is.na(lat), !is.na(long), #MUST HAVE VALID COORDINATE DATA.
             long >= -97.22904, long <= -89.48923, 
             lat >= 43.49952, lat <= 49.38436,
             !identificationcredibility %in% c("Negative", "Incorrect", "Unable to Confirm"), #THESE ARE FUNCTIONALLY NEGATIVE OBSERVATIONS, SO REMOVE.
             is.na(reviewed) | reviewed == TRUE, #ONLY ACCEPT REVIEWED RECORDS
             !is.na(year) #MUST HAVE A VALID YEAR
             ) %>%
      select(-c(location, coordinates, observationdate, reviewed, identificationcredibility, subjectnumber)) #JUNK THESE
    
    allDat = bind_rows(allDat, datTidy) #GROW OUTPUT
    
    #CONTINUE ONLY IF WE PULLED A FULL RECORD OF 1K
    if(nrow(nextDat) < 1000) {
      break
    } else {
      page = page + 1
    }
  }
}

#TRANSITION TO NEW TAXA NAMES ONCE
newNames = taxonCodes$common
names(newNames) = taxonCodes$eddmaps_name
allDat$species = unname(newNames[allDat$scientificname])
allDat$scientificname = NULL

#CONVERT TO SF ONCE
allDat_sf = allDat %>% 
  st_as_sf(crs = 4326, coords = c("long", "lat"))

lakesDB = readRDS("inputs/Static/allMNlakepolygons.rds") #MATCHING TO POLYGONS

EM_joined = st_join(x = allDat_sf, y = lakesDB, 
                     join = st_is_within_distance, dist = 50) %>% #JOIN TO WATERBODIES W/ BUFFER OF 50M
  filter(!is.na(DOW)) %>% #MUST HAVE JOINED (WOULD RECEIVE A DOW)
  st_drop_geometry() %>% #TRANSITION FROM OBSERVATION LOCATION TO WB CENTROID LOCATION FOR MAPPING
  st_as_sf(crs = 26915, coords = c("center_utm", "center_u_1")) %>% 
  st_transform(crs = 4326) %>% 
  arrange(DOW, species, year) %>% 
  mutate(possiblyGone = case_when( #SIMPLIFY INTO VALID OBSERVATIONS VERSUS VALID NON-OBSERVATIONS
    infestationstatus %in% c("Eradicated", "Negative") | managementstatus %in% c("Not Found", "Possibly Eradicated") ~ TRUE,
    TRUE ~ FALSE
  )) %>% 
  mutate(.by = c(DOW, species, year),
        goneNow = case_when( #IF, FOR A GIVEN DOW+SPECIES+YEAR, ALL OBSERVATIONS WERE "NOS", MARK.
          all(possiblyGone == TRUE) ~ TRUE,
          TRUE ~ FALSE
         )) %>% 
  mutate(.by = c(DOW, species), #FIND LAST SUCH YEAR FOR WBS W/ SUCH MARKS
         lastGoneYear = {
           goneYears = year[goneNow & !is.na(year)]
           if(length(goneYears) > 0) {
             max(goneYears)
           } else { -Inf }
         }) %>% 
  filter(year > lastGoneYear) %>% #FOR THOSE LAKES, FILTER OUT ALL OBSERVATIONS EARLIER IN TIME--WE NEED A POSITIVE AFTER THE LAST NEGATIVE. 
  filter(.by = c(DOW, species),#THEN, USUAL FILTERING TO FIRST VALID OBSERVATION REMAINING.
         year == min(year)) %>% 
  distinct(DOW, species, year, .keep_all = TRUE) %>% #RESOLVE ANY DUPLICATE RECORDS W/IN YEARS
  select(-c(infestationstatus, managementstatus, possiblyGone, goneNow, lastGoneYear)) #TIDY UP

#FILL IN OTHER COLUMNS THE COMBINED OBJECT WILL NEED. 
EM_joined$source = "EDDMapS Database"
EM_joined$connected = FALSE
EM_joined$traj = "positive"

t2 = Sys.time()
print(t2-t1)

saveRDS(EM_joined, "inputs/Dynamic/EDDMapS-current.rds")