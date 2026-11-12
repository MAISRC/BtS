# Match the project's invasive-taxa list to EDDMapS. Run from the project root.
# Requires jsonlite. API responses are cached so interrupted searches can resume.
# Add --refresh to fetch fresh taxonomy responses. query_ready means an identifier
# is selected, not that Minnesota occurrences or public coordinates exist.
api <- "https://api.bugwoodcloud.org/v2"
input_path <- "inputs/Static/invasives_list_revised_2026.csv"
cache_path <- "upstream/Admin/EDDMapS/cache/EDDMapS-taxonomy-search.rds"
output_path <- "upstream/Admin/EDDMapS/reference/EDDMapS-taxon-crosswalk.csv"
candidates_path <- "upstream/Admin/EDDMapS/cache/EDDMapS-taxonomy-candidates.csv"
taxa <- read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
stopifnot(all(c("scientific", "common") %in% names(taxa)), !anyDuplicated(taxa$scientific))
cache <- if (file.exists(cache_path) && !"--refresh" %in% commandArgs(trailingOnly = TRUE)) readRDS(cache_path) else list()
fetch <- function(path) {
  if (!is.null(cache[[path]])) return(cache[[path]]$data)
  url <- paste0(api, path)
  for (attempt in 1:3) {
    result <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE), error = function(e) e)
    if (!inherits(result, "error")) break
    if (attempt == 3) stop(url, ": ", result$message)
    Sys.sleep(attempt)
  }
  cache[[path]] <<- list(data = result, retrieved = as.character(Sys.Date()), url = url)
  saveRDS(cache, cache_path)
  Sys.sleep(0.1)
  result
}
value <- function(x, key) if (is.null(x[[key]])) "" else as.character(x[[key]])
name_of <- function(x) trimws(gsub(" +", " ", paste(value(x, "namepart1"), value(x, "namepart2"), value(x, "namepart3"))))
normalize <- function(x) tolower(trimws(gsub(" +", " ", x)))
search <- function(term) fetch(paste0("/subject?search=", utils::URLencode(term, reserved = TRUE)))
candidate_rows <- list()
crosswalk <- vector("list", nrow(taxa))
for (i in seq_len(nrow(taxa))) {
  scientific <- taxa$scientific[i]
  found <- search(scientific)
  exact <- Filter(function(x) normalize(name_of(x)) == normalize(scientific), found)
  if (!length(exact)) {
    genus <- strsplit(scientific, " ", fixed = TRUE)[[1]][1]
    found <- c(found, search(genus), search(taxa$common[i]), search(tail(strsplit(scientific, " ")[[1]], 1)))
  }
  if (length(found)) {
    found <- found[!duplicated(vapply(found, value, "", key = "subjectid"))]
    for (x in found) candidate_rows[[length(candidate_rows) + 1L]] <- data.frame(
      scientific = scientific, eddmaps_subject_id = value(x, "subjectid"),
      eddmaps_name = name_of(x), eddmaps_common = value(x, "subjectname"),
      valid_id = value(x, "validid"), valid_name = value(x, "validname"),
      source_url = paste0(api, "/subject/", value(x, "subjectid")), stringsAsFactors = FALSE)
  }
  status <- if (length(exact) == 1) "exact" else if (length(exact) > 1) "ambiguous" else "unmatched"
  x <- if (length(exact) == 1) exact[[1]] else list()
  ids <- unique(c(value(x, "subjectid"), value(x, "validid")))
  ids <- ids[nzchar(ids)]
  matched_name <- name_of(x)
  notes <- ""
  if (nzchar(value(x, "validid"))) {
    matched_name <- value(x, "validname")
    status <- "synonym_redirect"
    notes <- "EDDMapS explicitly redirects this name. Query both the original subject ID and valid_id."
  }
  crosswalk[[i]] <- data.frame(scientific = scientific, common = taxa$common[i],
    eddmaps_subject_ids = paste(ids, collapse = ";"), eddmaps_name = matched_name,
    match_status = status, query_ready = length(exact) == 1, notes = notes,
    source_url = if (length(ids)) paste0(api, "/subject/", tail(ids, 1)) else "",
    checked_on = as.character(Sys.Date()), stringsAsFactors = FALSE)
  if (i %% 15 == 0) message("Searched ", i, " / ", nrow(taxa), " taxa")
}
crosswalk <- do.call(rbind, crosswalk)
candidates <- do.call(rbind, candidate_rows)

# Reviewed exceptions preserve the intended source scope. No fuzzy match is accepted.
overrides_path <- "upstream/Admin/EDDMapS/reference/EDDMapS-taxon-overrides.csv"
overrides <- read.csv(overrides_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM", colClasses = "character")
stopifnot(!anyDuplicated(overrides$scientific), all(overrides$scientific %in% taxa$scientific))
crosswalk$evidence_url <- ""
for (i in seq_len(nrow(overrides))) {
  j <- match(overrides$scientific[i], crosswalk$scientific)
  # An old no-match finding must not suppress a newly available exact match.
  if (overrides$match_status[i] == "unmatched" && crosswalk$match_status[j] != "unmatched") next
  crosswalk[j, c("eddmaps_subject_ids", "match_status", "notes", "evidence_url")] <-
    overrides[i, c("eddmaps_subject_ids", "match_status", "notes", "evidence_url")]
  crosswalk$query_ready[j] <- nzchar(overrides$eddmaps_subject_ids[i])
}
query_rows <- list()
for (i in seq_len(nrow(crosswalk))) {
  if (!crosswalk$query_ready[i]) next
  seeds <- strsplit(crosswalk$eddmaps_subject_ids[i], ";", fixed = TRUE)[[1]]
  resolved <- list()
  for (seed in seeds) {
    detail <- fetch(paste0("/subject/", seed))
    if (nzchar(value(detail, "validid"))) detail <- fetch(paste0("/subject/", value(detail, "validid")))
    id <- value(detail, "subjectid")
    if (!nzchar(id)) stop("Subject detail has no ID for ", seed)
    resolved[[id]] <- detail
  }
  entries <- list()
  for (detail in resolved) {
    id <- value(detail, "subjectid")
    entries[[id]] <- list(id = id, name = name_of(detail), role = "canonical", canonical = id)
    for (synonym in detail$synonyms) {
      alias <- value(synonym, "subject")
      if (nzchar(alias)) entries[[alias]] <- list(id = alias, name = name_of(synonym), role = "synonym", canonical = id)
    }
  }
  crosswalk$eddmaps_subject_ids[i] <- paste(names(entries), collapse = ";")
  crosswalk$eddmaps_name[i] <- paste(vapply(resolved, name_of, ""), collapse = "; ")
  crosswalk$source_url[i] <- paste(paste0(api, "/subject/", names(resolved)), collapse = "; ")
  for (entry in entries) query_rows[[length(query_rows) + 1L]] <- data.frame(
    scientific = crosswalk$scientific[i], common = crosswalk$common[i],
    eddmaps_subject_id = entry$id, eddmaps_name = entry$name,
    canonical_subject_id = entry$canonical, query_role = entry$role,
    match_status = crosswalk$match_status[i],
    source_url = paste0(api, "/subject/", entry$id),
    mn_query_url = paste0(api, "/occurrence?state=27&subjectid=", entry$id, "&pagesize=1000&page=1"),
    checked_on = crosswalk$checked_on[i], stringsAsFactors = FALSE)
  if (i %% 15 == 0) message("Verified details for ", i, " / ", nrow(crosswalk), " source taxa")
}
queries <- do.call(rbind, query_rows)
stopifnot(nrow(crosswalk) == nrow(taxa), identical(crosswalk$scientific, taxa$scientific),
          !anyDuplicated(paste(queries$scientific, queries$eddmaps_subject_id)),
          all(queries$eddmaps_subject_id != ""),
          all(crosswalk$query_ready == nzchar(crosswalk$eddmaps_subject_ids)))
write.csv(crosswalk, output_path, row.names = FALSE, na = "")
write.csv(candidates, candidates_path, row.names = FALSE, na = "")
write.csv(queries, "upstream/Admin/EDDMapS/reference/EDDMapS-taxon-queries.csv", row.names = FALSE, na = "")
print(table(crosswalk$match_status))
message("Mapped source taxa: ", sum(crosswalk$query_ready), " / ", nrow(crosswalk))
message("Query identifiers: ", nrow(queries), "; unique: ", length(unique(queries$eddmaps_subject_id)))
print(crosswalk[!crosswalk$query_ready, c("scientific", "common")], row.names = FALSE)



