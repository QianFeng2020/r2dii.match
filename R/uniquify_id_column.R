#' Overwrite `id_direct_loantaker` and `id_ultimate_parent` with unique values
#'
#' Given a loanbook dataframe, this function overwrites columns
#' `id_direct_loantaker` and `id_ultimate_parent` of a loanbook dataframe to
#' generate values that are unique by every combination of the columns
#' `name_ultimate_parent`, `name_direct_loantaker` and
#' `sector_classification_direct_loantaker`.
#'
#' @param data A loanbook dataframe.
#' @param id_column A String giving the name of an `id_` column.
#'
#' @seealso [r2dii.dataraw::loanbook_description],
#'   [r2dii.dataraw::loanbook_demo].
#'
#' @return A loanbook dataframe with adjusted ids.
#'
#' @examples
#' library(dplyr)
#' library(r2dii.dataraw)
#'
#' loanbook_demo %>%
#'   select(id_direct_loantaker, everything()) %>%
#'   # To more clearly show the effect of uniquify_id_column()
#'   mutate(id_ultimate_parent = "anything")
#'
#' loanbook_demo %>%
#'   select(id_direct_loantaker, everything()) %>%
#'   uniquify_id_column(id_column = "id_direct_loantaker")
#'
#' # Same
#' loanbook_demo %>%
#'   select(id_ultimate_parent, everything()) %>%
#'   # To more clearly show the effect of uniquify_id_column()
#'   mutate(id_ultimate_parent = "anything")
#'
#' loanbook_demo %>%
#'   select(id_ultimate_parent, everything()) %>%
#'   uniquify_id_column(id_column = "id_ultimate_parent")
#' @noRd
uniquify_id_column <- function(data, id_column) {
  if (grepl("intermediate", id_column) && !has_name(data, id_column)) {
    warning(id_column, " not found in `data`.", call. = FALSE)
    return(data)
  }

  name_column <- id_column %>% replace_prefix(to = "name")
  crucial <- c("sector_classification_direct_loantaker", name_column, id_column)
  check_crucial_names(data, crucial)

  prefix <- sub("^N", "", toupper(snakecase_initial(name_column)))
  out <- data
  out[id_column] <- paste0(prefix, group_indices_of(out, id_column))
  out
}

replace_prefix <- function(x, to) {
  sub("^([^_]+)_(.*)$", glue("{to}_\\2"), x)
}

snakecase_initial <- function(x) {
  x %>%
    strsplit("_") %>%
    purrr::map(~ strsplit(., "")) %>%
    purrr::map_depth(2, dplyr::first) %>%
    purrr::map_chr(~ paste(.x, collapse = ""))
}

# Unique combination of `column` & `sector_classification_direct_loantaker`
group_indices_of <- function(data, column) {
  col_name <- replace_prefix(column, to = "name")
  dplyr::group_indices(
    data, !!rlang::sym(col_name), .data$sector_classification_direct_loantaker
  )
}
