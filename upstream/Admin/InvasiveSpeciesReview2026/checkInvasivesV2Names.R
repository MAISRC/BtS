# One-time review: run from the project root. No network access or output files.
# Evaluate the actual substitutions in global.R, without starting the app.
review_dir <- "upstream/Admin/InvasiveSpeciesReview2026"
old <- read.csv("inputs/Static/invasives_list_revised_2026.csv", stringsAsFactors = FALSE)
revised <- read.csv("inputs/Static/invasives_list_revised_2026_v2.csv", stringsAsFactors = FALSE)
crosswalk <- read.csv(file.path(review_dir, "invasives_list_revised_2026_v2_name_crosswalk.csv"),
                      stringsAsFactors = FALSE)
added <- setdiff(revised$scientific, old$scientific)
removed <- setdiff(old$scientific, revised$scientific)
stopifnot(nrow(revised) == 116L, length(added) == 15L, length(removed) == 27L,
          !anyDuplicated(revised$scientific), !anyDuplicated(tolower(revised$common)))
code <- readLines("global.R", encoding = "UTF-8", warn = FALSE)
invisible(parse(text = code))
stopifnot(!any(grepl("normalize_added_invasive_names|addedInvasiveNameCrosswalk", code)))
start <- match("#ADJUST SOME SPECIES NAMES FOR PROPER JOINING", code)
end <- match("#FIND THE SPECIES THAT OVERLAP W/ OUR INVASIVE SPECIES LIST AND FILTER TO ONLY THOSE", code)
stopifnot(!is.na(start), !is.na(end), start < end)
nas_rules <- parse(text = code[(start + 1L):(end - 1L)])
aliases <- c("Myxosoma cerebralis", "Heterosporis sutherlanda",
             "Piscine novirhabdovirus", "Oncorhynchus 2 novirhabdovirus",
             "Viral hemorrhagic septicemia virus", "Santee-Cooper ranavirus",
             "Largemouth bass virus", "Carp sprivivirus", "Rhabdovirus carpio",
             "Spring viremia of carp virus", "Spring viraemia of carp virus",
             "Cylindrospermopsis raciborskii", "Cyprinid herpesvirus 3", "Koi herpesvirus")
expected <- crosswalk$scientific[match(aliases, crosswalk$source_name)]
unsafe <- c("Sphaeridiotrema globulus", "Sphaeridiotrema sp.", "Heterosporis sp.",
            "Heterosporis", "Glossostigma diandrum", "Ranavirus sp.", "VHS-like symptoms")
NAS_sf <- data.frame(species = c(aliases, added, unsafe, NA_character_))
eval(nas_rules)
stopifnot(!anyNA(expected), identical(NAS_sf$species,
          c(expected, added, unsafe, NA_character_)))
nas <- read.csv("inputs/Dynamic/NAS-current.csv", stringsAsFactors = FALSE)
NAS_sf <- data.frame(species = nas$species)
eval(nas_rules)
nas_added_count <- sum(NAS_sf$species %in% added)
iwl <- read.csv("inputs/Dynamic/infestedWaters_cleanedNInclusive.csv",
                stringsAsFactors = FALSE, colClasses = c(DOW = "character"))
# Fixed-string lookup avoids treating the dollar sign as a regular expression anchor.
iwl_rule <- which(startsWith(code, 'IWL$species[IWL$species == "VHS"]'))
stopifnot(length(iwl_rule) == 1L)
IWL <- data.frame(species = iwl$species)
eval(parse(text = code[iwl_rule]))
vhs_common <- tolower(revised$common[revised$scientific == "Novirhabdovirus piscine"])
stopifnot(length(vhs_common) == 1L,
          all(IWL$species[iwl$species == "VHS"] == vhs_common),
          identical(IWL$species[iwl$species != "VHS"], iwl$species[iwl$species != "VHS"]))
cat("PASS: 116 taxa; 15 additions and 27 exclusions versus the original list; all 14 historical name substitutions resolve;\n",
    "canonical names, ambiguous labels, and missing values are preserved.\n",
    "Incoming NAS rows matching additions:", nas_added_count, "\n",
    "DNR VHS rows matched:", sum(iwl$species == "VHS"),
    "; with a DOW:", sum(iwl$species == "VHS" & !is.na(iwl$DOW)), "\n")
