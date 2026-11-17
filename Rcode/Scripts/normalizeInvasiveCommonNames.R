# Common-name labels used when combining invasive-species occurrence sources.
normalizeInvasiveCommonNames = function(species) {
  stayCapped = c("Chinese mystery snail", "Eurasian or hybrid watermilfoil",
                 "European valve snail", "European water-clover",
                 "Japanese mystery snail", "Java waterdropwort",
                 "Lumholtz's waterflea", "Ponto-Caspian scud",
                 "New Zealand mudsnail", "New Zealand mud snail")
  species[!species %in% stayCapped] = tolower(species[!species %in% stayCapped])
  species[species %in% "New Zealand mudsnail"] = "New Zealand mud snail"
  species[species %in% "yellow iris"] = "yellow flag"
  species[species %in% "hybrid cattail"] = "narrow-leaved cattail"
  species
}
