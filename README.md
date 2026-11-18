# Automobile Price Prediction in R

Reproducible regression analysis of the UCI Automobile dataset, using vehicle specifications to explain and predict automobile prices.

The project compares single-predictor, polynomial, and multiple linear regression models, then evaluates their performance on unseen observations. It demonstrates a complete introductory data-analysis workflow in base R: data cleaning, exploratory visualization, model development, evaluation, and diagnostics.

## Key findings

- The analysis uses 199 complete observations from the original 205-row dataset.
- Engine size was the strongest individual predictor among the specifications tested.
- The engine-size-plus-horsepower model performed best on the fixed 20% holdout set.
- The selected model achieved a test R² of approximately **0.869**, with an RMSE of approximately **$3,538**.
- Adding four predictors slightly improved training fit but did not outperform the two-predictor model on test RMSE.

## Questions explored

- Which individual vehicle specification is most strongly associated with price?
- Does a quadratic relationship improve the engine-size model?
- Does combining engine size and horsepower improve predictions?
- How well do the candidate models perform on unseen observations?

## Visualizations

### Vehicle specifications and price

These plots show the relationships between vehicle price and width, curb weight, engine size, and horsepower.

![Relationships between vehicle specifications and price](outputs/key_predictors.png)

### Linear versus quadratic engine-size models

This comparison tests whether a curved relationship describes the connection between engine size and price better than a straight line.

![Linear and quadratic engine-size regression models](outputs/engine_size_models.png)

### Model diagnostics

Residual diagnostic plots for the best-performing holdout model are available in [`outputs/best_model_diagnostics.png`](outputs/best_model_diagnostics.png).

## Methods

- Missing-value handling and complete-case filtering
- Exploratory data visualization
- Simple linear regression
- Quadratic regression
- Multiple linear regression
- Model comparison using AIC and R²
- Fixed 80/20 holdout evaluation
- Test RMSE, MAE, and R²
- Residual diagnostics

The analysis uses only base R; no additional packages are required.

## Repository structure

```text
automobile-price-analysis/
├── analysis.R                         # Complete reproducible analysis
├── data/
│   ├── imports-85.data                # UCI Automobile dataset
│   └── README.md                      # Dataset documentation
├── outputs/
│   ├── analysis_summary.txt            # Model summary and evaluation results
│   ├── best_model_diagnostics.png     # Residual diagnostic plots
│   ├── engine_size_models.png         # Linear/quadratic comparison
│   ├── key_predictors.png             # Exploratory visualizations
│   ├── model_evaluation.csv           # Holdout model metrics
│   └── single_model_comparison.csv    # Individual-predictor comparison
├── .gitignore
├── LICENSE
└── README.md
```

## How to run

1. Install [R](https://cran.r-project.org/).
2. Clone or download this repository.
3. Open a terminal in the repository root.
4. Run:

```bash
Rscript analysis.R
```

The script reads the included dataset, creates the `outputs/` directory if needed, and regenerates the tables, figures, diagnostics, and summary report.

## Results

The candidate models are ranked by test RMSE using a fixed random seed:

| Model | Test RMSE | Test MAE | Test R² |
|---|---:|---:|---:|
| Engine size + horsepower | $3,538 | $2,422 | 0.869 |
| Engine size + horsepower + curb weight + width | $3,598 | $2,249 | 0.865 |
| Engine size | $3,936 | $2,816 | 0.838 |
| Quadratic engine size | $3,974 | $2,858 | 0.835 |

See [`outputs/model_evaluation.csv`](outputs/model_evaluation.csv) for the complete evaluation table and [`outputs/single_model_comparison.csv`](outputs/single_model_comparison.csv) for individual-predictor results.

## Data source

The project uses the [UCI Automobile dataset](https://archive.ics.uci.edu/dataset/10/automobile), originally donated by Jeffrey C. Schlimmer. Missing values represented by `?` are converted to `NA`, and rows missing variables required by the analysis are excluded.

## Limitations

- The dataset is small and dates from 1985.
- Results depend on the selected holdout split, although the fixed seed makes this run reproducible.
- The model is intended for educational and portfolio use, not production vehicle pricing.
- Linear-model assumptions and influential observations should be reviewed before making operational decisions.

## Author

Josh Guzman
