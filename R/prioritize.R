#' Pick rows where `score` is 1 and `level` per loan is of highest `priority`
#'
#' @template ignores-but-preserves-existing-groups
#'
#' @param data A  dataframe, commonly the output of [match_name()].
#' @param priority One of:
#'   * `NULL`: defaults to the default level priority as returned by
#'   [prioritize_level()].
#'   * A character vector giving a custom priority.
#'   * A function to apply to the output of [prioritize_level()], e.g. `rev`.
#'   * A quosure-style lambda function, e.g. `~ rev(.x)`.
#'
#' @seealso [match_name()], [prioritize_level()].
#'
#' @family user-oriented
#'
#' @return A dataframe with a single row per loan, where `score` is 1 and
#'   priority level is highest.
#'
#' @export
#'
#' @examples
#' library(dplyr)
#'
#' # styler: off
#' matched <- tribble(
#'   ~sector, ~sector_ald,  ~score, ~id,  ~level,
#'   "coal",  "coal",       1,      "aa", "ultimate_parent",
#'   "coal",  "coal",       1,      "aa", "direct_loantaker",
#'   "coal",  "coal",       1,      "bb", "intermediate_parent",
#'   "coal",  "coal",       1,      "bb", "ultimate_parent",
#' )
#' # styler: on
#'
#' prioritize_level(matched)
#'
#' # Using default priority
#' prioritize(matched)
#'
#' # Using the reverse of the default priority
#' prioritize(matched, priority = rev)
#'
#' # Same
#' prioritize(matched, priority = ~ rev(.x))
#'
#' # Using a custom priority
#' bad_idea <- c("intermediate_parent", "ultimate_parent", "direct_loantaker")
#'
#' prioritize(matched, priority = bad_idea)
prioritize <- function(data, priority = NULL) {
  check_crucial_names(data, c("id", "level", "score", "sector", "sector_ald"))
  priority <- set_priority(data, priority = priority)

  old_groups <- dplyr::groups(data)
  perfect_matches <- filter(ungroup(data), .data$score == 1L)

  out <- perfect_matches %>%
    group_by(.data$id, .data$sector, .data$sector_ald) %>%
    prioritize_at(.at = "level", priority = priority) %>%
    ungroup()

  group_by(out, !!!old_groups)
}

set_priority <- function(data, priority) {
  priority <- priority %||% prioritize_level(data)

  if (inherits(priority, "function")) {
    f <- priority
    priority <- f(prioritize_level(data))
  }

  if (inherits(priority, "formula")) {
    f <- rlang::as_function(priority)
    priority <- f(prioritize_level(data))
  }

  known_levels <- sort(unique(data$level))
  unknown_levels <- setdiff(priority, known_levels)
  if (!identical(unknown_levels, character(0))) {
    warning(
      glue(
        "Ignoring `priority` levels not found in data.
        Did you mean to use one of: {paste0(known_levels, collapse = ', ')}?"
      ),
      call. = FALSE
    )
  }

  priority
}

#' Arrange unique `level` values in default order of `priority`
#'
#' @param data A dataframe, commonly the output of [match_name()].
#'
#' @return A character vector of the default level priority per loan.
#'
#' @export
#'
#' @examples
#' matched <- tibble::tibble(
#'   level = c(
#'     "intermediate_parent_1",
#'     "direct_loantaker",
#'     "direct_loantaker",
#'     "direct_loantaker",
#'     "ultimate_parent",
#'     "intermediate_parent_2"
#'   )
#' )
#' prioritize_level(matched)
prioritize_level <- function(data) {
  select_chr(
    # Sort sufixes: e.g. intermediate*1, *2, *n
    sort(unique(data$level)),
    tidyselect::matches("direct"),
    tidyselect::matches("intermediate"),
    tidyselect::matches("ultimate")
  )
}

#' Pick rows from a dataframe based on a priority set at some columns
#'
#' @param data A dataframe.
#' @param .at Most commonly, a character vector of one column name. For more
#'   general usage see the `.vars` argument to [dplyr::arrange_at()].
#' @param priority Most commonly, a character vector of the priority to
#'   re-order the column(x) given by `.at`.
#'
#' @return A dataframe, commonly with less rows than the input.
#'
#' @examples
#' library(dplyr)
#'
#' # styler: off
#' data <- tibble::tribble(
#'   ~x, ~y,
#'   1, "a",
#'   2, "a",
#'   2, "z",
#' )
#' # styler: on
#'
#' data %>% prioritize_at("y")
#'
#' data %>%
#'   group_by(x) %>%
#'   prioritize_at("y")
#'
#' data %>%
#'   group_by(x) %>%
#'   prioritize_at(.at = "y", priority = c("z", "a")) %>%
#'   arrange(x) %>%
#'   ungroup()
#' @noRd
prioritize_at <- function(data, .at, priority = NULL) {
  data %>%
    dplyr::arrange_at(.at, .funs = prioritize_impl, priority = priority) %>%
    dplyr::filter(dplyr::row_number() == 1L)
}

prioritize_impl <- function(x, priority) {
  forcats::fct_relevel(x, priority)
}
