# Resolve only the approved names of the 12 additions to the 2026 v2 list.
# Unmatched labels are preserved; ambiguous genera and misidentifications
# must not be treated as synonyms of a named species.
normalize_added_invasive_names <- function(x, crosswalk,
                                          output = c("scientific", "common", "app_common")) {
  output <- match.arg(output)
  stopifnot(all(c("source_name", "scientific", "common") %in% names(crosswalk)))
  key <- function(value) tolower(trimws(gsub("[[:space:]]+", " ", value)))
  stopifnot(!anyNA(crosswalk$source_name),
            !anyDuplicated(key(crosswalk$source_name)))
  result <- as.character(x)
  index <- match(key(result), key(crosswalk$source_name))
  found <- !is.na(index)
  target <- if (output == "scientific") crosswalk$scientific else crosswalk$common
  if (output == "app_common") target <- tolower(target)
  result[found] <- target[index[found]]
  result
}
