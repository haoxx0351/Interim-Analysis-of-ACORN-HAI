# Clear
rm(list = ls())

# Load packages
suppressPackageStartupMessages({
  require(pacman)
  pacman::p_load(dplyr,
                 survival,
                 glmnet,
                 car,
                 gt,
                 extrafont)
})
# Define working directory
wd <- "./"
setwd(wd)

# Load data
df <- readRDS("data/att_first28.RData")

# Load fonts
loadfonts()

# Acinetobacter, carbapenem-resistant
df <- as.data.frame(df[[1]])
df$ris_Carbapenem <- as.factor(ifelse(df$ris_Carbapenem == 1, 1, 0))

# LASSO
# For variable selection when there is multicollinearity among the predictors
# Matrix for factor
x.factors <- model.matrix(~ df$sex + df$country_region +
                            df$country_income + 
                            df$hpd_admreason +
                            df$icu_hd_ap + df$pathogen_combined_types+
                            df$ris_Carbapenems)[,-1]

# for num
x.factors <- as.matrix(data.frame(x.factors, df$age_new, 
                                  df$comorbidities_Chalson, 
                                  df$severity_score_scale))
#
y <- Surv(df$time, df$event == 1)

lasso <- glmnet(x.factors, y, family = "cox", alpha = 1)
#
par(mar=c(1,1,1,1))
plot(lasso, xvar="lambda", label=T)
#
set.seed(1234)
lasso_comp_cv <- cv.glmnet(x.factors, y,
                           family="cox", 
                           alpha=1,
                           nfolds=5)

plot(lasso_comp_cv)
coef(lasso_comp_cv, s="lambda.min")

###
x.factors.df <- data.frame(x.factors)
dummy_y <- rnorm(nrow(x.factors.df))

model <- lm(dummy_y ~ ., data = x.factors.df)

# Variance Inflation Factor (VIF)
vif_values <- vif(model)
vif_df <- as.data.frame(vif_values)
vif_df$vif_values <- round(vif_df$vif_values, 3)

# Creat table
table_row <- list(
  c("Age", NA),
  c(NA, vif_df$vif_values[15]),
  c("Sex", NA),
  c("Female", "—"),
  c("Male", vif_df$vif_values[1]),
  c("Region", NA),
  c("Eastern Mediterranean Region", "—"),
  c("South-East Asian Region", vif_df$vif_values[2]),
  c("Western Pacific Region", vif_df$vif_values[3]),
  c("World Bank income status", NA),
  c("High income", "—"),
  c("Upper middle income", vif_df$vif_values[4]),
  c("Lower middle income", vif_df$vif_values[5]),
  c("Low income", vif_df$vif_values[6]),
  c("Primary admission reason", NA),
  c("Infectious disease", "—"),
  c("Gastrointestinal disorder", vif_df$vif_values[7]),
  c("Neurological disease", vif_df$vif_values[8]),
  c("Pulmonary disease", vif_df$vif_values[9]),
  c("Trauma", vif_df$vif_values[10]),
  c("Others", vif_df$vif_values[11]),
  c("Charlson comorbidity index", NA),
  c(NA, vif_df$vif_values[16]),
  c("Severity score of disease", NA),
  c(NA, vif_df$vif_values[17]),
  c("ICU/HD admissions of enrolment", NA),
  c("No", "—"),
  c("Yes", vif_df$vif_values[12]),
  c("Types of pathogens", NA),
  c("Monomicrobial", "—"),
  c("Polymicrobial", vif_df$vif_values[13]),
  c("Acinetobacter", NA),
  c("Carbapenem-susceptible", "—"),
  c("Carbapenem-resistant", vif_df$vif_values[14])
)

# Bind the rows into a matrix
table_vif <- do.call(rbind, table_row)

#
table_vif <- table_vif %>%
  as.data.frame() %>%
  mutate(across(1, ~ ifelse(.x == "NA", "", .x)))

colnames(table_vif) <- c("Variables", "Variance inflation factor")

#
lasso_table <- table_vif %>%
  gt() %>%
  sub_missing(
    columns = 1:2,
    missing_text = ""
  ) %>%
  tab_style(
    style = list(cell_text(weight = "bold")),
    locations = cells_column_labels(everything())
  ) %>%
  tab_options(
    column_labels.border.top.color = "black",
    column_labels.border.top.width = px(2.5),
    column_labels.border.bottom.color = "black",
    column_labels.border.bottom.width = px(2.5),
    table_body.hlines.color = "white",
    table_body.hlines.width = px(0),
    table.border.bottom.color = "white",
    table.border.bottom.width = px(0),
    data_row.padding = px(0)
  ) %>%
  tab_style(
    style = cell_borders(
      sides = "bottom",
      color = "black",
      weight = px(2.5)
    ),
    locations = cells_body(
      rows = nrow(table_vif)
    )
  ) %>%
  cols_align(
    align = "center",
    columns = 2
  )  %>%
  tab_style(
    style = cell_text(align = "left", v_align = "middle"),
    locations = cells_column_labels(columns = 1)
  ) %>%
  tab_style(
    style = list(cell_text(weight = "bold")),
    locations = cells_body(
      columns = 1,
      rows = c(1, 3, 6, 10, 15, 22, 24, 26, 29, 32) 
    )
  ) %>%
  tab_style(
    style = cell_text(
      font = c("Times New Roman"),
      size = px(14)
    ),
    locations = list(
      cells_title(groups = "title"),
      cells_title(groups = "subtitle"),
      cells_column_labels(),
      cells_body()
    )
  ) 


print(lasso_table)

# Save
gtsave(lasso_table, filename = "output/table/LASSO_att28_car_aci.html")
