# Exercise the actual NAS pipeline in global.R, without sourcing app/network code.
suppressPackageStartupMessages({library(dplyr);library(sf)})
options(warn = 2)
source("Rcode/Scripts/normalizeInvasiveCommonNames.R")
expressions <- parse("global.R")
is_assignment <- function(e, name) is.call(e) && as.character(e[[1]]) %in% c("=", "<-") &&
  identical(e[[2]], as.name(name))
pipelines <- Filter(function(e) is_assignment(e,"NAS_joined") &&
  grepl("last_negative",paste(deparse(e),collapse=" "),fixed=TRUE),as.list(expressions))
stopifnot(length(pipelines)==1)
normalizers <- Filter(function(e) is.call(e) && as.character(e[[1]]) %in% c("=","<-") &&
  startsWith(paste(deparse(e[[2]]),collapse=""),"NAS_joined$status["),as.list(expressions))
run_rules <- function(input) {
  env <- new.env(parent=globalenv())
  env$NAS_joined <- input
  for (expression in normalizers) eval(expression,env)
  eval(pipelines[[1]],env)
  env$NAS_joined
}
inputs <- list(); expected <- list()
add_case <- function(id,years,statuses,expected_year=NULL,expected_traj="positive",species="taxon") {
  inputs[[length(inputs)+1L]] <<- data.frame(DOW=id,species=species,year=years,status=statuses)
  if (!is.null(expected_year)) expected[[length(expected)+1L]] <<-
    data.frame(DOW=id,species=species,year=expected_year,traj=expected_traj)
}
add_case("same_year_positive_negative",c(2020,2020),c("collected","eradicated"),2020)
add_case("same_year_negative_unknown",c(2020,2020),c("failed","unknown"))
add_case("restart",c(1990,2005,2010),c("collected","eradicated","established"),2010)
add_case("unknown_before_restart",c(1990,2005,2007,2010),c("collected","eradicated","unknown","collected"),2010)
add_case("unknown_after_positive",c(2000,2010),c("collected","unknown"),2000)
add_case("all_unknown",c(2000,2010),c("unknown","unknown"),2000,"unknown")
add_case("unknown_after_clearance",c(1990,2005,2010),c("collected","eradicated","unknown"))
add_case("only_negative",2005,"extirpated")
add_case("only_stocked",2005,"stocked")
add_case("unknown_before_positive",c(2000,2005),c("unknown","collected"),2005)
add_case("stocked_before_positive",c(1990,2005),c("stocked","established"),2005)
add_case("multiple_resets",c(1990,2000,2005,2010,2012),c("failed","collected","eradicated","established","unknown"),2010)
add_case("duplicate_latest_unknowns",c(2000,2010,2010),c("collected","unknown","unknown"),2000)
add_case("mixed_year_not_clearance",c(1990,2010,2010),c("collected","eradicated","collected"),1990)
add_case("missing_status",c(2000,2010),c(NA,"unknown"),2000,"unknown")
add_case("missing_year",c(NA,2005),c("eradicated","collected"),2005)
add_case("only_missing_year",NA,"collected")
add_case("unknown_then_clearance",c(2000,2005),c("unknown","eradicated"))
add_case("mixed_restart_year",c(2000,2010,2010),c("eradicated","unknown","collected"),2010)
add_case("locally_established",2000,"locally established",2000)
add_case("independent_groups",c(1990,2005),c("collected","eradicated"),species="cleared taxon")
add_case("independent_groups",c(1995,2010),c("collected","unknown"),1995,species="retained taxon")
input <- bind_rows(inputs)
expected <- bind_rows(expected) %>% arrange(DOW,species)
result <- run_rules(input) %>% arrange(DOW,species)
stopifnot(isTRUE(all.equal(as.data.frame(result),as.data.frame(expected),check.attributes=FALSE)),
  !inherits(result,"grouped_df"),!anyDuplicated(paste(result$DOW,result$species)))
# The same pipeline must retain sf geometry and CRS.
spatial <- st_as_sf(mutate(input,longitude=-93,latitude=45),crs=4326,coords=c("longitude","latitude"))
spatial_result <- run_rules(spatial)
stopifnot(inherits(spatial_result,"sf"),st_crs(spatial_result)$epsg==4326,
  isTRUE(all.equal(as.data.frame(st_drop_geometry(spatial_result) %>% arrange(DOW,species)),as.data.frame(expected),check.attributes=FALSE)))
stopifnot(nrow(run_rules(data.frame(DOW="gone",species="taxon",year=2000,status="eradicated")))==0)
cat("NAS trajectory checks passed: 22 scenarios, group isolation, and sf preservation.\n")
# Shared names must match known app labels and remain stable on repeat use.
raw_names <- c("Curly-leaf pondweed","Zebra mussel","Chinese mystery snail",
  "Eurasian or hybrid watermilfoil","New Zealand mudsnail","yellow iris","hybrid cattail",NA)
app_names <- c("curly-leaf pondweed","zebra mussel","Chinese mystery snail",
  "Eurasian or hybrid watermilfoil","New Zealand mud snail","yellow flag","narrow-leaved cattail",NA)
stopifnot(identical(normalizeInvasiveCommonNames(raw_names),app_names),
  identical(normalizeInvasiveCommonNames(app_names),app_names))
q <- read.csv("upstream/Admin/EDDMapS/reference/EDDMapS-taxon-queries.csv",stringsAsFactors=FALSE)
taxa <- read.csv("inputs/Static/invasives_list_revised_2026_v2.csv",stringsAsFactors=FALSE,fileEncoding="UTF-8-BOM")
stopifnot(nrow(q)==141,!anyDuplicated(q$eddmaps_subject_id),
  identical(q$common,normalizeInvasiveCommonNames(q$canonical_common)),
  identical(q$canonical_common,taxa$common[match(q$scientific,taxa$scientific)]),
  all(c(15300,57383) %in% q$eddmaps_subject_id[q$scientific=="Cyprinus carpio"]),
  all(q$common[q$scientific=="Cyprinus carpio"]=="common carp"),
  q$eddmaps_name[q$eddmaps_subject_id==57383]=="Cyprinus carpio carpio")
cat("Query table checks passed: 141 IDs, canonical labels, app names, and carp subspecies.\n")
existing_edd <- readRDS("inputs/Dynamic/EDDMapS-current.rds")
normalized_edd <- normalizeInvasiveCommonNames(existing_edd$species)
stopifnot(!anyNA(normalized_edd),all(normalized_edd %in% normalizeInvasiveCommonNames(taxa$common)))
cat("Existing EDDMapS RDS labels are compatible with the shared app normalization.\n")
for (path in c("Rcode/Scripts/normalizeInvasiveCommonNames.R","Rcode/Scripts/updateEDDMapS.R",
  "upstream/Admin/EDDMapS/scripts/matchEDDMapSTaxa.R")) invisible(parse(path))
cat("All modified R code parsed. No occurrence pull or app-output rewrite was performed.\n")
