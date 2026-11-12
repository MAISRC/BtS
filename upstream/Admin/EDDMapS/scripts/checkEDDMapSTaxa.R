# Small API smoke checks: one Minnesota occurrence per crosswalk identifier.
# This does not count occurrences or establish absence of geolocated records.
api <- "https://api.bugwoodcloud.org/v2"
queries <- read.csv("upstream/Admin/EDDMapS/reference/EDDMapS-taxon-queries.csv", stringsAsFactors = FALSE,
                    colClasses = "character")
output <- "upstream/Admin/EDDMapS/cache/EDDMapS-taxon-query-checks.csv"
checks <- vector("list", nrow(queries))
for (i in seq_len(nrow(queries))) {
  q <- queries[i, ]
  url <- paste0(api, "/occurrence?state=27&subjectid=", q$eddmaps_subject_id, "&pagesize=1&page=1")
  for (attempt in 1:3) {
    data <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE), error = function(e) e)
    if (!inherits(data, "error")) break
    if (attempt < 3) Sys.sleep(attempt)
  }
  status <- "no_MN_record_returned"
  location <- ""
  returned_id <- ""
  coords <- FALSE
  year <- ""
  if (inherits(data, "error")) {
    status <- "API_error"
  } else if (length(data)) {
    if (!is.list(data[[1]]) || is.null(data[[1]]$objectid)) stop("Unexpected response: ", url)
    record <- data[[1]]
    location <- if (is.null(record$location)) "" else record$location
    returned_id <- as.character(record$subjectnumber)
    in_mn <- grepl(", Minnesota, United States$", location)
    if (!nzchar(trimws(location))) {
      detail <- jsonlite::fromJSON(paste0(api, "/occurrence/", record$objectid), simplifyVector = FALSE)
      in_mn <- !is.null(detail$country) && !is.null(detail$state) &&
        detail$country %in% c("United States", "United States of America") && detail$state == "Minnesota"
    }
    allowed <- queries$eddmaps_subject_id[queries$scientific == q$scientific]
    status <- if (!in_mn) "non_MN_record_returned" else if (returned_id %in% allowed) "MN_record_returned" else "filter_mismatch"
    coords <- !is.null(record$coordinates) && nzchar(record$coordinates)
    if (!is.null(record$observationdate)) year <- substr(record$observationdate, 1, 4)
  }
  checks[[i]] <- data.frame(scientific = q$scientific, eddmaps_subject_id = q$eddmaps_subject_id,
    query_role = q$query_role, check_status = status, sample_location = location,
    returned_subject_id = returned_id, sample_has_coordinates = coords,
    sample_observation_year = year, checked_on = as.character(Sys.Date()),
    query_url = url, stringsAsFactors = FALSE)
  if (i %% 20 == 0 || i == nrow(queries)) {
    write.csv(do.call(rbind, checks[seq_len(i)]), output, row.names = FALSE, na = "")
    message("Checked ", i, " / ", nrow(queries), " identifiers")
  }
  Sys.sleep(0.1)
}
checks <- do.call(rbind, checks)
print(table(checks$check_status))
message("Source taxa with at least one returned MN record: ",
  length(unique(checks$scientific[checks$check_status == "MN_record_returned"])))
stopifnot(!any(checks$check_status %in% c("API_error", "filter_mismatch")))


