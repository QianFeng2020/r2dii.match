library(dplyr)
library(r2dii.dataraw)

test_that("prioritize w/ 2 identical rows except for sector yields 2 rows", {
  out <- prioritize(fake_matched(sector = c("shipping", "automotive")))
  expect_equal(nrow(out), 2L)
})

test_that("prioritize w/ 2 identical rows except for sector_ald yields 2 rows", {
  out <- prioritize(fake_matched(sector_ald = c("shipping", "automotive")))
  expect_equal(nrow(out), 2L)
})

test_that("prioritize w/ full demo datasets throws no error", {
  expect_error(
    loanbook_demo %>%
      slice(4:5) %>%
      match_name(ald_demo) %>%
      prioritize(priority = "ultimate_parent"),
    NA
  )
})

test_that("prioritize errors gracefully if data lacks crucial columns", {
  expect_error(prioritize(fake_matched()), NA)

  expect_error(
    prioritize(select(fake_matched(), -id)),
    class = "missing_names"
  )
  expect_error(
    prioritize(select(fake_matched(), -level)),
    class = "missing_names"
  )
  expect_error(
    prioritize(select(fake_matched(), -score)),
    class = "missing_names"
  )
  expect_error(
    prioritize(select(fake_matched(), -sector_ald)),
    class = "missing_names"
  )
  expect_error(
    prioritize(select(fake_matched(), -sector)),
    class = "missing_names"
  )
})

test_that("prioritize errors gracefully with bad `priority`", {
  expect_warning(
    prioritize(fake_matched(), priority = c("bad1", "bab2")),
    "[Ii]gnoring.*levels"
  )
  expect_warning(
    prioritize(fake_matched(), priority = c("bad1", "bab2")),
    "[Uu]nknown.*bad1.*bab2"
  )
})

test_that("prioritize picks score equal to 1", {
  matched <- fake_matched(score = c(1, 0.9))
  expect_equal(min(prioritize(matched)$score), 1)
})

test_that("prioritize picks the highetst level per loan", {
  # styler: off
  id_level <- tibble::tribble(
    ~id,                 ~level,
   "aa",      "ultimate_parent",
   "aa",     "direct_loantaker",  # pick this **
   "bb",  "intermediate_parent",  # pick this **
   "bb",      "ultimate_parent",
  )
  # styler: on
  matched <- fake_matched(id = id_level$id, level = id_level$level)

  expect_equal(
    prioritize(matched)$level,
    c("direct_loantaker", "intermediate_parent") # **
  )
})

test_that("prioritize takes a `priority` function or lambda", {
  matched <- fake_matched(level = c("direct_loantaker", "ultimate_parent"))
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
  expect_equal(
    prioritize(fake_matched(level = c("z", "a")), priority = "z")$level,
    "z"
  )
})

test_that("prioritize ignores existing groups", {
  # styler: off
  matched <- tibble::tribble(
    ~id, ~other_id, ~level,
    "a",         1,    "z",  # pick **
    "a",         2,    "a",
    "b",         3,    "z",  # pick **
    "b",         4,    "a",
  ) %>%
    # Crucial columns with toy values
    mutate(sector = "coal", sector_ald = "coal", score = 1) %>%
    group_by(other_id)
  # styler: on

  expect_equal(
    prioritize(matched, priority = "z")$level,
    c("z", "z") # **
  )
})

test_that("prioritize previous preserves groups", {
  matched <- fake_matched(other_id = 1:4) %>%
    group_by(other_id, score)

  expect_equal(
    dplyr::group_vars(prioritize(matched)),
    c("other_id", "score")
  )
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

test_that("prioritize does not warn if a group has not all priority items", {
  expect_warning(
    fake_matched(level = c("a", "z"), new = level) %>%
      group_by(new) %>%
      prioritize(priority = c("z", "a")),
    NA
  )
})
