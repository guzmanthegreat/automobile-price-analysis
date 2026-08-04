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
    evaluation = comparison
  ),
  file = file.path("outputs", "analysis_summary.txt")
)

cat("Model comparison (ordered by test RMSE):\n")
print(comparison, row.names = FALSE)
cat("\nSelected model:", best_model_name, "\n")
cat("Results and plots were saved in outputs/.\n")
