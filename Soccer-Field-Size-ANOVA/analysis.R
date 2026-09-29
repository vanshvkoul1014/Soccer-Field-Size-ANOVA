# Reproducible version of the R workflow in the group report's code appendix.
# Run from the repository root: Rscript analysis.R

required <- c("openxlsx", "ggplot2", "car")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Install required packages: install.packages(c(",
       paste(sprintf('"%s"', missing), collapse = ", "), "))")
}

input <- "data/StadiumGoals_dataset.xlsx"
if (!file.exists(input)) stop("Run this script from the repository root.")
raw <- openxlsx::read.xlsx(input)
# openxlsx converts spaces to dots in the header names by default.
needed <- c("Size.Cateogory", "League", "Games", "Goals.(season-23/24)")
if (!all(needed %in% names(raw))) {
  stop("Unexpected spreadsheet columns: ", paste(names(raw), collapse = ", "))
}
dat <- raw[!is.na(raw$Size.Cateogory) & !is.na(raw$Games) &
             !is.na(raw[["Goals.(season-23/24)"]]), needed]
if (any(dat$Games <= 0)) stop("Games must be positive")
dat$Size.Category <- factor(dat$Size.Cateogory,
                            levels = c("Small", "Medium", "Large", "Xlarge"))
if (anyNA(dat$Size.Category)) stop("Unexpected size category")
dat$goals_per_game <- dat[["Goals.(season-23/24)"]] / dat$Games
dat$League <- factor(dat$League)

model <- aov(goals_per_game ~ Size.Category, data = dat)
anova_table <- summary(model)[[1]]
ss_between <- anova_table[1, "Sum Sq"]
ss_total <- sum(anova_table[, "Sum Sq"])
eta_squared <- ss_between / ss_total
cat("Observations:", nrow(dat), "\n")
print(anova_table)
cat(sprintf("Eta squared: %.4f\n", eta_squared))
cat(sprintf("Durbin-Watson statistic: %.4f\n",
            car::durbinWatsonTest(model)$dw))

dir.create("figures", showWarnings = FALSE)
save_plot <- function(name, plot, width = 7, height = 5) {
  ggplot2::ggsave(file.path("figures", name), plot, width = width,
                  height = height, dpi = 180)
}
p_league <- ggplot2::ggplot(dat, ggplot2::aes(x = League, y = goals_per_game)) +
  ggplot2::geom_point(size = 2) + ggplot2::theme_bw() +
  ggplot2::labs(title = "League and goals per game", y = "Goals per game")
save_plot("league_goals_generated.png", p_league)

# Exploratory interaction chart; league/size cells are sparse and unbalanced.
means <- aggregate(goals_per_game ~ League + Size.Category, dat, mean)
p_interaction <- ggplot2::ggplot(means, ggplot2::aes(
  Size.Category, goals_per_game, color = League, group = League)) +
  ggplot2::geom_point() + ggplot2::geom_line() + ggplot2::theme_bw() +
  ggplot2::labs(title = "League by field-size category",
                x = "Field-size category", y = "Mean goals per game")
save_plot("interaction_generated.png", p_interaction)

png("figures/qq_generated.png", width = 1100, height = 800, res = 160)
car::qqPlot(residuals(model), distribution = "norm", envelope = 0.90,
            id = FALSE, pch = 20, ylab = "Residuals")
dev.off()

diagnostics <- data.frame(residuals = residuals(model),
                          fitted = fitted(model), index = seq_along(residuals(model)))
p_residual <- ggplot2::ggplot(diagnostics,
  ggplot2::aes(x = fitted, y = residuals)) + ggplot2::geom_point(size = 2) +
  ggplot2::theme_bw() + ggplot2::labs(title = "Residuals versus fitted",
    x = "Fitted goals per game", y = "Residuals")
save_plot("residuals_generated.png", p_residual)
p_index <- ggplot2::ggplot(diagnostics,
  ggplot2::aes(x = index, y = residuals)) +
  ggplot2::geom_point() + ggplot2::geom_line() +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  ggplot2::theme_bw() + ggplot2::labs(title = "Residuals by spreadsheet order",
    x = "Row order", y = "Residuals")
save_plot("index_generated.png", p_index)
