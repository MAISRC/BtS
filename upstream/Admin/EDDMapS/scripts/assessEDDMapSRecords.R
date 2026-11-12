# Download all Minnesota EDDMapS pages for the current reviewed crosswalk.
# Run from the project root after matchEDDMapSTaxa.R. Requires jsonlite.
# --resume reuses compact pages in the current snapshot; a default run starts anew.
options(timeout = 180)
api <- "https://api.bugwoodcloud.org/v2"
# The live service caps requests above 2000, despite its 3000-row documentation.
# A verified 1000-row request avoids treating a capped response as the last page.
page_size <- 1000L
taxa_path <- "inputs/Static/invasives_list_revised_2026.csv"
queries_path <- "upstream/Admin/EDDMapS/reference/EDDMapS-taxon-queries.csv"
output_dir <- "upstream/Admin/EDDMapS/assessment"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
snapshot_path <- file.path(output_dir, "snapshot.rds")
source_hash <- unname(tools::md5sum(taxa_path))
queries_hash <- unname(tools::md5sum(queries_path))
resume <- "--resume" %in% commandArgs(trailingOnly = TRUE)
if (resume && file.exists(snapshot_path)) {
  snapshot <- readRDS(snapshot_path)
  stopifnot(identical(snapshot$source_hash, source_hash), identical(snapshot$queries_hash, queries_hash))
} else {
  snapshot <- list(started = format(Sys.time(), tz = "UTC", usetz = TRUE),
    source_hash = source_hash, queries_hash = queries_hash,
    folder = paste0("pages-", format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")))
  saveRDS(snapshot, snapshot_path)
}
page_dir <- file.path(output_dir, snapshot$folder)
dir.create(page_dir, recursive = TRUE, showWarnings = FALSE)
queries <- read.csv(queries_path, stringsAsFactors = FALSE, colClasses = "character")
taxa <- read.csv(taxa_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
stopifnot(all(queries$scientific %in% taxa$scientific), !anyDuplicated(queries$eddmaps_subject_id))
get_value <- function(x, key) {
  v <- x[[key]]
  if (is.null(v) || !length(v)) return(NA_character_)
  paste(as.character(v), collapse = ";")
}
fields <- c("objectid", "subjectnumber", "coordinates", "geogwkt", "geogtype",
  "observationdate", "yearaccuracy", "eradicationstatus", "infestationstatus",
  "location", "fipscode", "centroidtype", "coordinateuncertaintyinmeters",
  "dateupdated", "dateentered", "reviewed", "identificationcredibility")
empty_page <- as.data.frame(setNames(rep(list(character()), length(fields)), fields))
descendant_path <- file.path(output_dir, "descendant-details.rds")
descendant_cache <- if (resume && file.exists(descendant_path)) readRDS(descendant_path) else list()
page_logs <- list()
all_pages <- list()
for (i in seq_len(nrow(queries))) {
  q <- queries[i, ]
  page_number <- 1L
  seen <- character()
  taxon_total <- 0L
  repeat {
    cache_file <- file.path(page_dir, paste0(q$eddmaps_subject_id, "-", page_number, ".rds"))
    url <- paste0(api, "/occurrence?state=27&subjectid=", q$eddmaps_subject_id,
      "&pagesize=", page_size, "&page=", page_number)
    reusable <- FALSE
    if (resume && file.exists(cache_file)) {
      saved <- readRDS(cache_file)
      reusable <- identical(saved$url, url) ||
        (page_number == 1L && nrow(saved$rows) < page_size)
    }
    if (!reusable) {
      for (attempt in 1:4) {
        result <- tryCatch({
          temporary <- tempfile(tmpdir = page_dir, fileext = ".json")
          parsed <- tryCatch({
            utils::download.file(url, temporary, method = "libcurl", mode = "wb", quiet = TRUE)
            response_bytes <- file.info(temporary)$size
            jsonlite::fromJSON(temporary, simplifyVector = FALSE)
          }, finally = unlink(temporary))
          if (length(parsed) && (!is.list(parsed[[1]]) || is.null(parsed[[1]]$objectid)))
            stop("Unexpected occurrence response")
          rows <- if (!length(parsed)) empty_page else as.data.frame(
            do.call(rbind, lapply(parsed, function(x) vapply(fields, function(k) get_value(x, k), ""))),
            stringsAsFactors = FALSE)
          list(rows = rows, url = url, downloaded = format(Sys.time(), tz = "UTC", usetz = TRUE),
               bytes = response_bytes)
        }, error = function(e) e)
        if (!inherits(result, "error")) break
        if (attempt == 4) stop(url, ": ", result$message)
        Sys.sleep(attempt * 2)
      }
      saved <- result
      saveRDS(saved, cache_file)
      Sys.sleep(0.15)
    }
    rows <- saved$rows
    if (nrow(rows) > page_size) stop("API exceeded requested page size: ", url)
    if (nrow(rows)) {
      in_mn <- (!is.na(rows$fipscode) & grepl("^27", rows$fipscode)) |
        (!is.na(rows$location) & grepl(", Minnesota, United States$", rows$location))
      allowed <- queries$eddmaps_subject_id[queries$scientific == q$scientific]
      if (!all(in_mn)) stop("State filter mismatch: ", url)
      # Parent-taxon searches also return subspecies. Verify the ancestry of every
      # additional identifier rather than discarding legitimate descendants.
      for (returned_id in setdiff(unique(rows$subjectnumber), allowed)) {
        detail <- descendant_cache[[returned_id]]
        if (is.null(detail)) {
          detail <- jsonlite::fromJSON(paste0(api, "/subject/", returned_id), simplifyVector = FALSE)
          descendant_cache[[returned_id]] <- detail
          saveRDS(descendant_cache, descendant_path)
        }
        ancestors <- vapply(detail$taxonomy, function(x) as.character(x$id), "")
        valid_id <- if (is.null(detail$validid)) "" else as.character(detail$validid)
        if (!any(c(ancestors, valid_id) %in% allowed)) stop("Taxon filter mismatch: ", url, " returned ", returned_id)
      }
      if (all(rows$objectid %in% seen)) stop("Pagination repeated a previous page: ", url)
      seen <- union(seen, rows$objectid)
      rows$scientific <- q$scientific
      rows$query_subject_id <- q$eddmaps_subject_id
      rows$query_page <- page_number
      all_pages[[length(all_pages) + 1L]] <- rows
    }
    page_logs[[length(page_logs) + 1L]] <- data.frame(scientific = q$scientific,
      query_subject_id = q$eddmaps_subject_id, page = page_number, records = nrow(rows),
      response_bytes = saved$bytes, downloaded = saved$downloaded, query_url = url,
      stringsAsFactors = FALSE)
    taxon_total <- taxon_total + nrow(rows)
    if (nrow(rows) < page_size) break
    message("  ", q$scientific, ": completed page ", page_number, " (", taxon_total, " rows so far)")
    page_number <- page_number + 1L
  }
  message(i, "/", nrow(queries), " ", q$scientific, " [", q$eddmaps_subject_id, "]: ", taxon_total, " rows")
  write.csv(do.call(rbind, page_logs), file.path(output_dir, "page-log.csv"), row.names = FALSE, na = "")
}
records <- do.call(rbind, all_pages)
if (is.null(records)) stop("No records returned")
raw_count <- nrow(records)
# A live record can be repeated across aliases or shifting page boundaries.
records <- records[order(records$dateupdated, decreasing = TRUE, na.last = TRUE), ]
records <- records[!duplicated(records$objectid), ]
distinct_downloaded <- nrow(records)
# State ID 27 is reused internationally (e.g. Tabasco, Mexico). FIPS prefixes
# alone are not sufficient. Require the returned location to identify Minnesota,
# and resolve missing location labels through the individual-record endpoint.
geo_path <- file.path(output_dir, "geography-details.rds")
geo_cache <- if (resume && file.exists(geo_path)) readRDS(geo_path) else list()
records$is_minnesota <- !is.na(records$location) & grepl(", Minnesota, United States$", records$location)
blank_location <- is.na(records$location) | !nzchar(trimws(records$location))
records$geographic_exclusion_reason <- ifelse(records$is_minnesota, "", "Location label identifies a different region")
for (i in which(blank_location)) {
  id <- records$objectid[i]
  detail <- geo_cache[[id]]
  if (is.null(detail)) {
    detail <- jsonlite::fromJSON(paste0(api, "/occurrence/", id), simplifyVector = FALSE)
    geo_cache[[id]] <- detail
    saveRDS(geo_cache, geo_path)
  }
  country <- get_value(detail, "country")
  state <- get_value(detail, "state")
  records$is_minnesota[i] <- !is.na(country) && !is.na(state) &&
    country %in% c("United States", "United States of America") && state == "Minnesota"
  records$geographic_exclusion_reason[i] <- if (records$is_minnesota[i]) "" else
    paste0("Individual record country=", country, "; state=", state)
}
excluded_geography <- records[!records$is_minnesota, ]
write.csv(excluded_geography, file.path(output_dir, "excluded-geography.csv"), row.names = FALSE, na = "")
saveRDS(records, file.path(output_dir, "downloaded-record-audit.rds"))
records <- records[records$is_minnesota, ]
records$latitude <- NA_real_
records$longitude <- NA_real_
records$coordinate_source <- NA_character_
for (i in seq_len(nrow(records))) {
  coordinate <- records$coordinates[i]
  xy <- if (!is.na(coordinate)) suppressWarnings(as.numeric(strsplit(coordinate, ",", fixed = TRUE)[[1]])) else numeric()
  if (length(xy) == 2 && all(is.finite(xy)) && abs(xy[1]) <= 90 && abs(xy[2]) <= 180) {
    records$latitude[i] <- xy[1]
    records$longitude[i] <- xy[2]
    records$coordinate_source[i] <- "coordinates"
  } else if (!is.na(records$geogwkt[i]) && grepl("^POINT\\s*\\(", records$geogwkt[i], ignore.case = TRUE)) {
    point <- sub("^POINT\\s*\\(([^)]+)\\).*$", "\\1", records$geogwkt[i], ignore.case = TRUE)
    xy <- suppressWarnings(as.numeric(strsplit(trimws(point), "\\s+")[[1]]))
    if (length(xy) == 2 && all(is.finite(xy)) && abs(xy[1]) <= 180 && abs(xy[2]) <= 90) {
      records$longitude[i] <- xy[1]
      records$latitude[i] <- xy[2]
      records$coordinate_source[i] <- "point_wkt"
    }
  }
}
records$year <- suppressWarnings(as.integer(substr(records$observationdate, 1, 4)))
records$has_coordinates <- is.finite(records$latitude) & is.finite(records$longitude)
records$has_year <- !is.na(records$year) & records$year > 0 & records$year <= as.integer(format(Sys.Date(), "%Y"))
records$usable <- records$has_coordinates & records$has_year
records$status <- tolower(trimws(ifelse(is.na(records$eradicationstatus), records$infestationstatus, records$eradicationstatus)))
records$candidate_presence <- records$usable & records$status %in% c("positive", "treated")
records$state <- "MN"
# Preserve the full compact audit, but keep the requested occurrence output to five columns.
saveRDS(records, file.path(output_dir, "record-audit.rds"))
# Returned subspecies IDs can be additional to the original query crosswalk.
# This bridge preserves the source grouping without adding occurrence columns.
write.csv(unique(data.frame(species_code = records$subjectnumber,
  species = records$scientific, stringsAsFactors = FALSE)),
  file.path(output_dir, "observed-taxon-crosswalk.csv"), row.names = FALSE)
grouped <- records[records$usable, c("latitude", "longitude", "scientific", "state", "year")]
minimal <- records[records$usable, c("latitude", "longitude", "subjectnumber", "state", "year")]
names(minimal)[names(minimal) == "subjectnumber"] <- "species_code"
write.csv(minimal, file.path(output_dir, "occurrences-all-statuses.csv"), row.names = FALSE, na = "")
presence <- grouped[records$status[records$usable] %in% c("positive", "treated"), ]
names(presence)[names(presence) == "scientific"] <- "species"
stopifnot(all(presence$species %in% taxa$scientific))
write.csv(presence, file.path(output_dir, "occurrences-positive-or-treated.csv"), row.names = FALSE, na = "")
summary_rows <- lapply(taxa$scientific, function(name) {
  x <- records[records$scientific == name, ]
  logs <- do.call(rbind, page_logs)
  data.frame(scientific = name, common = taxa$common[match(name, taxa$scientific)],
    mapped = name %in% queries$scientific,
    downloaded_rows = sum(logs$records[logs$scientific == name]),
    excluded_non_minnesota = sum(excluded_geography$scientific == name), distinct_records = nrow(x),
    usable_records = sum(x$usable), missing_coordinates = sum(!x$has_coordinates),
    missing_or_invalid_year = sum(!x$has_year),
    positive = sum(x$status == "positive", na.rm = TRUE), treated = sum(x$status == "treated", na.rm = TRUE),
    negative = sum(x$status == "negative", na.rm = TRUE), eradicated = sum(x$status == "eradicated", na.rm = TRUE),
    usable_positive_or_treated = sum(x$candidate_presence),
    stringsAsFactors = FALSE)
})
summary <- do.call(rbind, summary_rows)
write.csv(summary, file.path(output_dir, "taxon-summary.csv"), row.names = FALSE, na = "")
status_summary <- as.data.frame(table(status = records$status, usable = records$usable, useNA = "ifany"))
write.csv(status_summary, file.path(output_dir, "status-summary.csv"), row.names = FALSE)
metrics <- data.frame(metric = c("listed_taxa", "mapped_taxa", "identifiers", "requests", "response_bytes",
  "downloaded_rows", "distinct_downloaded_records", "excluded_non_minnesota", "distinct_records", "duplicate_record_ids", "taxa_with_records", "usable_records",
  "missing_coordinates", "missing_or_invalid_year", "usable_positive_or_treated", "taxa_with_usable_positive_or_treated",
  "distinct_species_coordinate_year_rows", "distinct_presence_species_coordinate_year_rows"),
  count = c(nrow(taxa), length(unique(queries$scientific)), nrow(queries), length(page_logs),
    sum(vapply(page_logs, function(x) x$response_bytes, 0)), raw_count, distinct_downloaded, nrow(excluded_geography), nrow(records), raw_count - distinct_downloaded,
    length(unique(records$scientific)), sum(records$usable), sum(!records$has_coordinates), sum(!records$has_year),
    sum(records$candidate_presence), length(unique(records$scientific[records$candidate_presence])),
    nrow(unique(grouped)), nrow(unique(grouped[records$status[records$usable] %in% c("positive", "treated"), ]))))
write.csv(metrics, file.path(output_dir, "counts.csv"), row.names = FALSE)
snapshot$finished <- format(Sys.time(), tz = "UTC", usetz = TRUE)
saveRDS(snapshot, snapshot_path)
stopifnot(sum(summary$distinct_records) == nrow(records), sum(summary$usable_records) == nrow(minimal),
          sum(summary$usable_positive_or_treated) == nrow(presence), !anyDuplicated(records$objectid))
print(metrics, row.names = FALSE)
print(head(summary[order(summary$distinct_records, decreasing = TRUE), c("scientific", "distinct_records", "usable_records", "usable_positive_or_treated")], 12), row.names = FALSE)






