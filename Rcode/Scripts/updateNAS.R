library(dplyr)
jsonlite::fromJSON(
  "https://nas.er.usgs.gov/api/v2/occurrence/search?state=MN"
)$results %>%
  dplyr::select(species = scientificName,
                latitude = decimalLatitude,
                longitude = decimalLongitude,
                year, 
                status) %>% 
  write.csv(file = "inputs/Dynamic/NAS-current.csv", row.names = FALSE)
