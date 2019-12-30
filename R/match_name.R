#' Match a loanbook (lbk) and asset-level datasets (ald) by the `name_*` columns
#'
#' `match_name()` scores the match between names in a loanbook dataset (columns
#' `name_direct_loantaker` and `name_ultimate_parent`) with names in an
#' asset-level dataset (colum n `name_company`). The raw names are first
#' transformed and stored in a `simpler_name` column, then the similarity between
#' the `simpler_name` columns in each of the loanbook and ald datasets is scored
#' using [stringdist::stringsim()].
#'
#' The process to create the `simpler_name` columns applies best practices
#' commonly used in name matching algorithms, such as:
#' * Remove special characters.
#' * Replace language specific characters.
#' * Abbreviate certain names to reduce their importance in the matching.
#' * Spell out numbers to increase their importance.
#'
#' @inherit match_all_against_all
#' @inheritParams restructure_loanbook_for_matching
#' @param min_score A number (length-1) to set the minimum `score` values you
#'   want to pick.
#'
#' @return A dataframe with the same columns as the loanbook data with
#'   additional columns: `id_lkb`, `sector_lbk`, `sector_ald`, `source_lbk`,
#'   `simpler_name_lbk`, `simpler_name_ald`, `score`, `name_ald`.
#'
#' @export
#'
#' @examples
#' library(dplyr)
#' library(r2dii.dataraw)
#'
#' match_name(loanbook_demo, ald_demo)
#'
#' match_name(
#'   loanbook_demo, ald_demo,
#'   min_score = 0.9,
#'   by_sector = FALSE
#' )
match_name <- function(loanbook,
                       ald,
                       by_sector = TRUE,
                       min_score = 0.8,
                       method = "jw",
                       p = 0.1,
                       overwrite = NULL) {
  prep_lbk <- suppressMessages(
    restructure_loanbook_for_matching(loanbook, overwrite = overwrite)
  )
  prep_ald <- restructure_ald_for_matching(ald)

  matched <- match_all_against_all(
    prep_lbk, prep_ald,
    by_sector = by_sector,
    method = method,
    p = p
  )

  matched %>%
    pick_min_score(min_score) %>%
    restore_cols_sector_name_and_others(prep_lbk, prep_ald) %>%
    restore_cols_from_loanbook(loanbook) %>%
    prefer_perfect_match_by(.data$simpler_name_lbk)
}

suffix_names <- function(data, suffix, names = NULL) {
  if (is.null(names)) {
    return(suffix_all_names(data, suffix))
  } else {
    suffix_some_names(data, suffix, names)
  }
}

suffix_all_names <- function(data, suffix) {
  set_names(data, paste0, suffix)
}

suffix_some_names <- function(data, suffix, names) {
  newnames_oldnames <- set_names(names, paste0, suffix)
  rename(data, !!newnames_oldnames)
}


pick_min_score <- function(data, min_score) {
  data %>%
    filter(.data$score >= min_score) %>%
    unique()
}

restore_cols_sector_name_and_others <- function(matched, prep_lbk, prep_ald) {
  matched %>%
    left_join(suffix_names(prep_lbk, "_lbk"), by = "simpler_name_lbk") %>%
    left_join(suffix_names(prep_ald, "_ald"), by = "simpler_name_ald")
}

restore_cols_from_loanbook <- function(matched, loanbook) {
  level_cols <- c("name_ultimate_parent", "name_direct_loantaker")

  with_level_cols <- matched %>%
    tidyr::pivot_wider(
      names_from = "level_lbk",
      values_from = "name_lbk",
      names_prefix = "name_"
    )

  left_join(
    suffix_names(with_level_cols, "_lbk", level_cols),
    suffix_names(loanbook, "_lbk"),
    by = paste0(level_cols, "_lbk")
  )
}

prefer_perfect_match_by <- function(data, ...) {
  data %>%
    group_by(...) %>%
    filter(none_is_one(.data$score) | some_is_one(.data$score)) %>%
    ungroup()
}

none_is_one <- function(x) {
  all(x != 1L)
}

some_is_one <- function(x) {
  any(x == 1L) & x == 1L
}
