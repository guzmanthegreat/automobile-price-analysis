# Automobile Price Prediction Analysis
# Author: Josh Guzman
#
# Explores how engine size, horsepower, curb weight, and vehicle width relate
# to automobile price using simple, polynomial, and multiple regression.

options(stringsAsFactors = FALSE)

data_url <- paste0(
  "https://archive.ics.uci.edu/ml/machine-learning-databases/",
  "autos/imports-85.data"
)

column_names <- c(
  "symboling", "normalized_losses", "make", "fuel_type", "aspiration",
  "num_doors", "body_style", "drive_wheels", "engine_location",
  "wheelbase", "length", "width", "height", "curbweight", "engine_type",
  "num_cylinders", "enginesize", "fuel_system", "bore", "stroke",
  "compression_ratio", "horsepower", "peakrpm", "city_mpg", "highway_mpg",
  "price"
)

dir.create("data", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
data_path <- file.path("data", "imports-85.data")

if (!file.exists(data_path)) {
  message("Downloading the UCI Automobile dataset...")
  tryCatch(
    download.file(data_url, data_path, mode = "wb", quiet = TRUE),
    error = function(e) {
      stop(
        "The dataset could not be downloaded. Check your internet connection ",
        "and try again. Original error: ", conditionMessage(e)
      )
    }
  )
}

automobiles <- read.csv(
  data_path,
  header = FALSE,
  col.names = column_names,
  na.strings = "?",
  strip.white = TRUE
)

# Keep complete observations for the variables used in this analysis.
analysis_columns <- c("price", "width", "curbweight", "enginesize", "horsepower")
cars <- automobiles[complete.cases(automobiles[analysis_columns]), analysis_columns]

cat("Rows in raw dataset:", nrow(automobiles), "\n")
cat("Complete rows used:", nrow(cars), "\n\n")

# Exploratory plots ----------------------------------------------------------
png(file.path("outputs", "key_predictors.png"), width = 1200, height = 900, res = 140)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
plot(cars$width, cars$price, xlab = "Width (in.)", ylab = "Price (USD)",
     main = "Price vs. Width", pch = 19, col = "#377EB8AA")
plot(cars$curbweight, cars$price, xlab = "Curb Weight (lb)", ylab = "Price (USD)",
     main = "Price vs. Curb Weight", pch = 19, col = "#4DAF4AAA")
plot(cars$enginesize, cars$price, xlab = "Engine Size (cu. in.)", ylab = "Price (USD)",
     main = "Price vs. Engine Size", pch = 19, col = "#984EA3AA")
plot(cars$horsepower, cars$price, xlab = "Horsepower", ylab = "Price (USD)",
     main = "Price vs. Horsepower", pch = 19, col = "#FF7F00AA")
dev.off()

# Single-predictor models ----------------------------------------------------
single_models <- list(
  width = lm(price ~ width, data = cars),
  curb_weight = lm(price ~ curbweight, data = cars),
  engine_size = lm(price ~ enginesize, data = cars),
  horsepower = lm(price ~ horsepower, data = cars)
)

single_results <- data.frame(
  model = names(single_models),
  r_squared = vapply(single_models, function(model) summary(model)$r.squared, numeric(1)),
  aic = vapply(single_models, AIC, numeric(1))
)
single_results <- single_results[order(single_results$aic), ]
write.csv(single_results, file.path("outputs", "single_model_comparison.csv"), row.names = FALSE)

# Test whether curvature improves the engine-size relationship.
engine_linear <- lm(price ~ enginesize, data = cars)
engine_quadratic <- lm(price ~ enginesize + I(enginesize^2), data = cars)

x_grid <- seq(min(cars$enginesize), max(cars$enginesize), length.out = 300)
quadratic_predictions <- predict(engine_quadratic, newdata = data.frame(enginesize = x_grid))

png(file.path("outputs", "engine_size_models.png"), width = 1000, height = 700, res = 140)
plot(cars$enginesize, cars$price,
     xlab = "Engine Size (cu. in.)", ylab = "Price (USD)",
     main = "Linear and Quadratic Engine-Size Models",
     pch = 19, col = "#55555588")
abline(engine_linear, col = "#E41A1C", lwd = 3)
lines(x_grid, quadratic_predictions, col = "#377EB8", lwd = 3)
legend("topleft", c("Linear", "Quadratic"), col = c("#E41A1C", "#377EB8"),
       lty = 1, lwd = 3, bty = "n")
dev.off()

# Multiple regression and holdout evaluation --------------------------------
set.seed(42)
train_rows <- sample(seq_len(nrow(cars)), size = floor(0.8 * nrow(cars)))
train <- cars[train_rows, ]
test <- cars[-train_rows, ]

candidate_models <- list(
  engine_size = lm(price ~ enginesize, data = train),
  engine_size_quadratic = lm(price ~ enginesize + I(enginesize^2), data = train),
  engine_and_horsepower = lm(price ~ enginesize + horsepower, data = train),
  four_predictors = lm(price ~ enginesize + horsepower + curbweight + width, data = train)
)

model_metrics <- function(model, test_data) {
  predictions <- predict(model, newdata = test_data)
  errors <- test_data$price - predictions
  c(
    AIC = AIC(model),
    train_r_squared = summary(model)$r.squared,
    test_RMSE = sqrt(mean(errors^2)),
    test_MAE = mean(abs(errors)),
    test_r_squared = 1 - sum(errors^2) /
      sum((test_data$price - mean(test_data$price))^2)
  )
}

comparison <- as.data.frame(t(vapply(
  candidate_models,
  model_metrics,
  numeric(5),
  test_data = test
)))
comparison$model <- rownames(comparison)
rownames(comparison) <- NULL
comparison <- comparison[c("model", "AIC", "train_r_squared", "test_RMSE", "test_MAE", "test_r_squared")]
comparison <- comparison[order(comparison$test_RMSE), ]
write.csv(comparison, file.path("outputs", "model_evaluation.csv"), row.names = FALSE)

# Five-fold cross-validation -------------------------------------------------
# Cross-validation checks whether the holdout ranking is reasonably stable
# across several train/test partitions of the complete analysis dataset.
model_formulas <- list(
  engine_size = price ~ enginesize,
  engine_size_quadratic = price ~ enginesize + I(enginesize^2),
  engine_and_horsepower = price ~ enginesize + horsepower,
  four_predictors = price ~ enginesize + horsepower + curbweight + width
)

set.seed(42)
k_folds <- 5
fold_ids <- sample(rep(seq_len(k_folds), length.out = nrow(cars)))

cv_rows <- do.call(rbind, lapply(names(model_formulas), function(model_name) {
  do.call(rbind, lapply(seq_len(k_folds), function(fold) {
    cv_train <- cars[fold_ids != fold, ]
    cv_test <- cars[fold_ids == fold, ]
    cv_model <- lm(model_formulas[[model_name]], data = cv_train)
    cv_predictions <- predict(cv_model, newdata = cv_test)
    cv_errors <- cv_test$price - cv_predictions
    data.frame(
      model = model_name,
      fold = fold,
      RMSE = sqrt(mean(cv_errors^2)),
      MAE = mean(abs(cv_errors)),
      R_squared = 1 - sum(cv_errors^2) /
        sum((cv_test$price - mean(cv_test$price))^2)
    )
  }))
}))

cv_summary <- aggregate(
  cbind(RMSE, MAE, R_squared) ~ model,
  data = cv_rows,
  FUN = mean
)
names(cv_summary)[names(cv_summary) == "RMSE"] <- "cv_RMSE"
names(cv_summary)[names(cv_summary) == "MAE"] <- "cv_MAE"
names(cv_summary)[names(cv_summary) == "R_squared"] <- "cv_R_squared"
cv_summary <- cv_summary[order(cv_summary$cv_RMSE), ]
write.csv(cv_summary, file.path("outputs", "cross_validation.csv"), row.names = FALSE)

# Compare holdout and cross-validation error visually.
plot_order <- comparison$model
cv_rmse <- cv_summary$cv_RMSE[match(plot_order, cv_summary$model)]
performance_values <- rbind(comparison$test_RMSE, cv_rmse)
colnames(performance_values) <- plot_order

png(file.path("outputs", "model_performance.png"), width = 1200, height = 750, res = 140)
barplot(
  performance_values,
  beside = TRUE,
  col = c("#377EB8", "#4DAF4A"),
  names.arg = c("Engine size +\nhorsepower", "Four predictors",
                "Engine size", "Quadratic\nengine size"),
  ylab = "Prediction error (USD)",
  main = "Model Performance: Holdout vs. 5-Fold Cross-Validation",
  legend.text = c("20% holdout RMSE", "5-fold CV RMSE"),
  args.legend = list(x = "topright", bty = "n")
)
dev.off()

best_model_name <- comparison$model[1]
best_model <- candidate_models[[best_model_name]]

png(file.path("outputs", "best_model_diagnostics.png"), width = 1200, height = 900, res = 140)
par(mfrow = c(2, 2))
plot(best_model)
dev.off()

capture.output(
  list(
    selected_by_test_rmse = best_model_name,
    model_summary = summary(best_model),
    holdout_evaluation = comparison,
    cross_validation = cv_summary
  ),
  file = file.path("outputs", "analysis_summary.txt")
)

# Create a short business-facing summary for portfolio readers.
best_cv_name <- cv_summary$model[1]
best_cv_rmse <- cv_summary$cv_RMSE[1]
business_summary <- c(
  "Business-facing summary",
  "========================",
  "",
  paste("Objective: estimate automobile prices from observable vehicle specifications."),
  paste("Data: 205 vehicles in the source dataset;", nrow(cars), "complete observations used."),
  paste("Recommended model:", best_model_name),
  paste("Holdout RMSE: $", format(round(comparison$test_RMSE[1]), big.mark = ","), sep = ""),
  paste("Holdout MAE: $", format(round(comparison$test_MAE[1]), big.mark = ","), sep = ""),
  paste("Holdout R-squared:", round(comparison$test_r_squared[1], 3)),
  paste("Best 5-fold cross-validation model:", best_cv_name),
  paste("5-fold CV RMSE: $", format(round(best_cv_rmse), big.mark = ","), sep = ""),
  "",
  "Interpretation:",
  "Engine size and horsepower provide a useful baseline for estimating vehicle price.",
  "The holdout split favors the engine-size-plus-horsepower model, while 5-fold",
  "cross-validation favors the four-predictor model. Both evaluations support",
  "using multiple vehicle specifications rather than engine size alone.",
  "A pricing tool should be recalibrated with newer market data before operational use.",
  "",
  "Recommended next steps:",
  "Add vehicle make, body style, fuel economy, and age or mileage when available.",
  "Validate the model on current listings and monitor errors by vehicle segment."
)
writeLines(business_summary, file.path("outputs", "business_summary.txt"))

cat("Model comparison (ordered by test RMSE):\n")
print(comparison, row.names = FALSE)
cat("\nCross-validation comparison (ordered by CV RMSE):\n")
print(cv_summary, row.names = FALSE)
cat("\nSelected model:", best_model_name, "\n")
cat("Results and plots were saved in outputs/.\n")
