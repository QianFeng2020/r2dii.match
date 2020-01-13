library(dplyr)
library(r2dii.dataraw)

test_that("prioritize works with loanbook_demo and ald_demo", {
  expect_error(
    loanbook_demo %>%
      slice(4:5) %>%
      match_name(ald_demo) %>%
      prioritize(priority = "ultimate_parent"),
    NA
  )
})

test_that("prioritize errors gracefully if data lacks crucial columns", {
  expect_error(prioritize(tibble(bad = 1)), "must have.*names")

  matched <- tibble(id = "a", level = "a", score = 1)
  expect_error(prioritize(matched), NA)

  expect_error(
    prioritize(select(matched, -id)),
    "must have.*names"
  )
  expect_error(
    prioritize(select(matched, -level)),
    "must have.*names"
  )
  expect_error(
    prioritize(select(matched, -score)),
    "must have.*names"
  )
})

test_that("prioritize errors gracefully with bad `priority`", {
  matched <- tibble(id = "a", level = c("z", "a"), score = 1)
  expect_warning(
    prioritize(matched, priority = c("bad1", "bab2")),
    "[Ii]gnoring.*levels"
  )
  expect_warning(
    prioritize(matched, priority = c("bad1", "bab2")),
    "[Uu]nknown.*bad1.*bab2"
  )
})

test_that("prioritize picks score equal to 1", {
  # styler: off
  matched <- tibble::tribble(
    ~id,             ~level, ~score,
   "aa", "direct_loantaker",      1,
   "bb", "direct_loantaker",    0.9,
    )
  # styler: on

  expect_equal(min(prioritize(matched)$score), 1L)
})

test_that("prioritize picks priority level per loan", {
  # styler: off
  matched <- tibble::tribble(
    ~id,                  ~level, ~score,
   "aa",       "ultimate_parent",      1,
   "aa",      "direct_loantaker",      1,  # pick this
   "bb",   "intermediate_parent",      1,  # pick this
   "bb",      "ultimate_parent",       1,
    )
  # styler: on

  out <- prioritize(matched)
  expect_equal(
    out$level, c("direct_loantaker", "intermediate_parent")
  )
})

test_that("prioritize picks the highetst level per loan", {
  # styler: off
  matched <- tibble::tribble(
     ~id,                  ~level, ~score,
    "aa",       "ultimate_parent",      1,
    "aa",      "direct_loantaker",      1,  # pick this
    "bb",   "intermediate_parent",      1,  # pick this
    "bb",      "ultimate_parent",       1,
    )
  # styler: on

  out <- prioritize(matched)
  expect_equal(
    out$level, c("direct_loantaker", "intermediate_parent")
  )
})

test_that("prioritize takes a `priority` function
          or lambda", {
  level <- c("direct_loantaker", "ultimate_parent")
  matched <- tibble(id = "aa", level, score = 1)

  out <- prioritize(matched, priority = NULL)
  expect_equal(out$level, "direct_loantaker")

  # Reverse with function
  out <- prioritize(matched, priority = rev)
  expect_equal(out$level, "ultimate_parent")

  # Reverse with lambda
  out <- prioritize(matched, priority = ~ rev(.x))
  expect_equal(out$level, "ultimate_parent")
})

test_that("prioritize is sensitive to `priority`", {
  matched <- tibble(id = "aa", level = c("z", "a"), score = 1)
  expect_equal(
    prioritize(matched, priority = "z")$level,
    "z"
  )
})

test_that("prioritize ignores other groups", {
  # styler: off
  matched <- tibble::tribble(
    ~id, ~level, ~score, ~other_id,
    "a",    "z",      1,         1,
    "a",    "a",      1,         2,
    "b",    "z",      1,         3,
    "b",    "a",      1,         4,
  ) %>%
    group_by(other_id)
  # styler: on

  out <- prioritize(matched, priority = "z")

  expect_equal(
    out$level,
    c("z", "z")
  )
})

test_that("prioritize previous preserves groups", {
  # styler: off
  matched <- tibble::tribble(
    ~id, ~level, ~score, ~other_id,
    "a",    "z",      1,         1,
    "a",    "a",      1,         2,
    "b",    "z",      1,         3,
    "b",    "a",      1,         4,
  ) %>%
    group_by(other_id, score)
  # styler: on

  out <- prioritize(matched, priority = "z")
  expect_true(dplyr::is_grouped_df(out))
  expect_equal(dplyr::group_vars(out), c("other_id", "score"))
})

test_that("prioritize_level otputs expected vector", {
  matched <- tibble(
    level = c(
      "intermediate_parent_1",
      "direct_loantaker",
      "direct_loantaker",
      "direct_loantaker",
      "ultimate_parent",
      "intermediate_parent_2"
    )
  )
  expect_equal(
    prioritize_level(matched),
    c(
      "direct_loantaker",
      "intermediate_parent_1",
      "intermediate_parent_2",
      "ultimate_parent"
    )
  )
})

test_that("prioritize_at with ungrouped data picks the highest priority row", {
  out <- tibble(x = c("a", "z")) %>%
    prioritize_at(.at = "x", priority = c("z", "a"))

  expect_equal(out$x, "z")
})

test_that("prioritize_at with grouped data picks one row per group", {
  out <- tibble(
    x = c(1, 2, 2),
    y = c("a", "a", "z")
  ) %>%
    group_by(x) %>%
    prioritize_at(.at = "y", priority = c("z", "a")) %>%
    arrange(x)

  expect_equal(out$y, c("a", "z"))
})

test_that("prioritize_at does not warn if a group has not all priority items", {
  expect_warning(
    tibble(x = c("a", "z"), y = x) %>%
      group_by(y) %>%
      prioritize_at(.at = "x", priority = c("z", "a")),
    NA
  )
})

test_that("prioritize_at accepts `priority = NULL`", {
  expect_error(
    tibble(x = "a") %>% prioritize_at("x"),
    NA
  )
})