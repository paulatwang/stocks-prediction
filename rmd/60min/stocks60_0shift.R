knitr::opts_chunk$set(echo = TRUE,
                      collapse = FALSE,
                      warning = FALSE, 
                      tidy = TRUE)
options(width=120)

library(RcmdrMisc)
library(jtools)
library(timeSeries)
library(astsa)
library(lubridate)
library(zoo)
library(tsbox)

library(lme4)
library(reghelper)
library(RcmdrMisc)
library(interactions)
library(dplyr)
library(reshape2)
library(ggplot2)
library(gridExtra)

library(ggpubr)
theme_set(theme_pubclean())

stocks60 <- read.table("data_articles_hourly.csv", header=TRUE, stringsAsFactors=TRUE, sep=",", na.strings="NA", dec=".", strip.white=TRUE)  # READ DATA
stocks60$dt_hourly <- as.POSIXct(stocks60$dt_hourly, tz="EST") # CONVERT DT TO POSIX
col60 <- c("season_workday_hourly", "season_month_hourly","tf1_hourly", "tf2_hourly", "tf3_hourly", "tf4_hourly", "tf5_hourly", "tf6_daily") 
stocks60[col60] <- lapply(stocks60[col60], as.factor) # CONVERT CAT VARs TO FACTORs

stocks60$stocks_hourly_diff = stocks60$stocks_hourly %>% diff() %>% append(NA, 0) # Difference for moving averages
stocks60$stocks_hourly_diff_ln = stocks60$stocks_hourly %>% log() %>% diff() %>% append(NA, 0) # Log then difference for variance stabilization

stocks60$day_count = stocks60$dt_hourly %>% date() %>% as.integer() - stocks60$dt_hourly %>% date() %>% as.integer() %>% min() + 1 # Counting the days

stocks60$morality = 
  stocks60$care_p_hourly*stocks60$care_sent_hourly + 
  stocks60$fairness_p_hourly*stocks60$fairness_sent_hourly +
  stocks60$loyalty_p_hourly*stocks60$loyalty_sent_hourly +
  stocks60$authority_p_hourly*stocks60$authority_sent_hourly +
  stocks60$sanctity_p_hourly*stocks60$sanctity_sent_hourly

stocks60$morality_lag = lag(stocks60$morality) # lag morality index

stocks60$care_p_hourly_lag = lag(stocks60$care_p_hourly) # lag moral probabilities
stocks60$fairness_p_hourly_lag = (stocks60$fairness_p_hourly)
stocks60$loyalty_p_hourly_lag = lag(stocks60$loyalty_p_hourly)
stocks60$authority_p_hourly_lag = lag(stocks60$authority_p_hourly)
stocks60$sanctity_p_hourly_lag = lag(stocks60$sanctity_p_hourly)

stocks60$care_sent_hourly_lag = lag(stocks60$care_sent_hourly) # lag moral sentiments
stocks60$fairness_sent_hourly_lag = lag(stocks60$fairness_sent_hourly)
stocks60$loyalty_sent_hourly_lag = lag(stocks60$loyalty_sent_hourly)
stocks60$authority_sent_hourly_lag = lag(stocks60$authority_sent_hourly)
stocks60$sanctity_sent_hourly_lag = lag(stocks60$sanctity_sent_hourly)

stocks60$care_lag = stocks60$care_p_hourly_lag * stocks60$care_sent_hourly_lag # lag probability*sentiments
stocks60$fairness_lag = stocks60$fairness_p_hourly_lag * stocks60$fairness_sent_hourly_lag
stocks60$loyalty_lag = stocks60$loyalty_p_hourly_lag * stocks60$loyalty_sent_hourly_lag
stocks60$authority_lag = stocks60$authority_p_hourly_lag * stocks60$authority_sent_hourly_lag
stocks60$sanctity_lag = stocks60$sanctity_p_hourly_lag * stocks60$sanctity_sent_hourly_lag

stocks60_ordered = stocks60[, c(1, 24, 2:4, 16:21, 5, 22, 23, 25, 6:15, 27:36, 26, 37:41)] # REORDER COLUMNS
stocks60_ordered %>% colnames() # DISPLAY COL NAMES
stocks60ts = ts(stocks60_ordered) # MAKE TIME SERIES

plot(stocks60ts[,"stocks_hourly"]) # PLOT INITIAL DATA

acf(stocks60_ordered$stocks_hourly, lag.max = NULL, type = c("correlation"), plot = TRUE, na.action = na.pass) # ACF FOR NON-TRANSFORMED DATA
acf(stocks60_ordered$stocks_hourly, lag.max = NULL, type = c("partial"), plot = TRUE, na.action = na.pass) # PACF FOR NON-TRANSFORMED DATA

acf(stocks60_ordered$stocks_hourly_diff_ln, lag.max = NULL, type = c("correlation"), plot = TRUE, na.action = na.pass) # ACF FOR TRANSFORMED DATA
acf(stocks60_ordered$stocks_hourly_diff_ln, lag.max = NULL, type = c("partial"), plot = TRUE, na.action = na.pass) # PACF FOR TRANSFORMED DATA

plot(stocks60ts[,"stocks_hourly_diff_ln"]) # UNSTABLE VARIANCE IN CONTRACTION AND RECOVERY PERIOD - NEED GARCH MODEL

hist(stocks60_ordered[16:25]) # PROB & SENT
hist(stocks60_ordered[26:35]) # PROB & SENT LAG
hist(stocks60_ordered[, c(15,36)]) # MORALITY & MORALITY LAG
hist(stocks60_ordered[37:41]) # FOUNDATIONS LAG
hist(stocks60_ordered[14]) # TRANSFORMED STOCKS

# VIOLIN
plot_violin <- function(input) { 
  return(input + geom_violin(trim = FALSE) + stat_summary(fun.data = "mean_sdl", fun.args = list(mult = 1), geom = "pointrange", color = "black"))}

# DOUBLE VIOLIN
plot_violin2 <- function(input) {
  return(input + geom_violin(aes(color = tf2_hourly), trim = FALSE,position = position_dodge(0.9)) + geom_boxplot(aes(color = tf2_hourly),width = 0.60, position = position_dodge(0.9)) + scale_color_manual(values = c("#00AFBB","#E7B800")))}

# BOXPLOT
plot_boxplot <- function(input) {
  return(input +  geom_boxplot(notch = TRUE, fill = "lightgray") +stat_summary(fun.y = mean, geom = "point",shape = 18, size = 2.5, color = "#FC4E07"))}

# SCATTERPLOT
plot_scatter <- function(input) {
  return(ggplot(stocks60_ordered, aes(input, stocks_hourly_diff_ln, color=tf2_hourly)) + geom_point() + geom_smooth(method=lm) +scale_color_manual(values = c('#999999','#E69F00')) + theme(legend.position=c(0,1), legend.justification=c(0,1)))}

# X DENSITY
plot_xdensity <- function(input) {
  return(ggplot(stocks60_ordered, aes(input, fill=tf2_hourly)) +geom_density(alpha=.5) +scale_fill_manual(values = c('#999999','#E69F00')) + theme(legend.position = "none") )}

# Y DENSITY
plot_ydensity <- function() {return(ggplot(stocks60_ordered, aes(stocks_hourly_diff_ln, fill=tf2_hourly)) +geom_density(alpha=.5) +scale_fill_manual(values = c('#999999','#E69F00')) +theme(legend.position = "none") )}

# BLANK PLOT
plot_blank <- function() {
  return(ggplot() + geom_blank(aes(1,1)) +theme(plot.background = element_blank(),panel.grid.major = element_blank(),panel.grid.minor = element_blank(),panel.border = element_blank(), panel.background = element_blank(),axis.title.x = element_blank(),axis.title.y = element_blank(),axis.text.x = element_blank(),axis.text.y = element_blank(),axis.ticks = element_blank()))}

e <- ggplot(stocks60, aes(x = tf2_hourly, y = morality_lag)) 
plot_boxplot(e) # MORALITY BOX PLOT
plot_violin(e) # MORALITY VIOLIN PLOT

stocks60_foundations_long = melt(stocks60_ordered[, c(7,37:41)]) 
e1 <-  ggplot(stocks60_foundations_long, aes(x = variable, y = value))
plot_violin(e1) # FOUNDATIONS VIOLIN PLOT
plot_boxplot(e1) # FOUNDATIONS BOX PLOT
plot_violin2(e1) # FOUNDATIONS BY TF VIOLIN PLOT

scatterPlot <- plot_scatter(stocks60_ordered$morality_lag)
xdensity <- plot_xdensity(stocks60_ordered$morality_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # MORALITY PLOT

scatterPlot <- plot_scatter(stocks60_ordered$care_lag)
xdensity <- plot_xdensity(stocks60_ordered$care_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # CARE PLOT

scatterPlot <- plot_scatter(stocks60_ordered$fairness_lag)
xdensity <- plot_xdensity(stocks60_ordered$fairness_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # FAIRNESS PLOT

scatterPlot <- plot_scatter(stocks60_ordered$loyalty_lag)
xdensity <- plot_xdensity(stocks60_ordered$loyalty_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # LOYALTY PLOT

scatterPlot <- plot_scatter(stocks60_ordered$authority_lag)
xdensity <- plot_xdensity(stocks60_ordered$authority_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # AUTHORITY PLOT

scatterPlot <- plot_scatter(stocks60_ordered$sanctity_lag)
xdensity <- plot_xdensity(stocks60_ordered$sanctity_lag)
ydensity <- plot_ydensity()
blankPlot <- plot_blank()
grid.arrange(xdensity, blankPlot, scatterPlot, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # SANCTITY PLOT

omtted <- na.omit(stocks60_ordered)

outlier_rm_IQR <- function(data, df_str, col_str, threshold){
  Q <- quantile(data, probs=c(.25, .75), na.rm = FALSE) # 25/75 QUANTILES AFTER REMOVING ROW 1 (NA row)
  iqr <- IQR(data) # IQR AFTER REMOVING ROW 1 (NA row)
  upper <- Q[2]+threshold*iqr # Upper Range for outliers
  lower <- Q[1]-threshold*iqr # Lower Range for outliers
  df <- get(df_str)
  column <- get(df_str)[col_str]
  a <- subset.data.frame(df, column > lower)
  b <- subset.data.frame(df, column < upper)
  return(intersect(a,b))
}

a <- outlier_rm_IQR(omtted$morality_lag[-1], "stocks60_ordered", "morality_lag", 2.5)
b <- outlier_rm_IQR(omtted$stocks_hourly_diff_ln[-1], "stocks60_ordered", "stocks_hourly_diff_ln", 2.5)

stocks60_outrm <- intersect(a,b)
stocks60_outrm_moralityonly <- outlier_rm_IQR(omtted$morality_lag[-1], "stocks60_ordered", "morality_lag", 2.5)

stocks60.model.lm <- lm(stocks_hourly_diff_ln ~ tf2_hourly * morality_lag,data = omtted)

stocks60.model.lm.foundations <- lm(stocks_hourly_diff_ln ~ tf2_hourly * (care_lag +fairness_lag +loyalty_lag +authority_lag +sanctity_lag), data = omtted)

stocks60.model.lme.null <-lmer(stocks_hourly_diff_ln ~ 1 + (1|day_count), data = omtted, REML=TRUE)

stocks60.model.lme <- lmer(stocks_hourly_diff_ln ~ (1 + season_intraday_hourly + tf2_hourly*morality_lag + (1 + season_intraday_hourly | day_count)), data = omtted, REML = TRUE)

stocks60.model.lme.foundations <- lmer(stocks_hourly_diff_ln ~  (1 + season_intraday_hourly + tf2_hourly*(care_lag + fairness_lag + loyalty_lag + authority_lag + sanctity_lag) + ( 1 + season_intraday_hourly | day_count)), data = omtted, REML = TRUE)

stocks60.model.lm.outrm <- lm(stocks_hourly_diff_ln ~ tf2_hourly * morality_lag,data = stocks60_outrm_moralityonly)

stocks60.model.lm.foundations.outrm <- lm(stocks_hourly_diff_ln ~ tf2_hourly * (care_lag +fairness_lag +loyalty_lag +authority_lag +sanctity_lag), data = stocks60_outrm_moralityonly)

stocks60.model.lme.null.outrm <-lmer(stocks_hourly_diff_ln ~ 1 + (1|day_count), data = stocks60_outrm_moralityonly, REML=TRUE)

stocks60.model.lme.outrm <- lmer(stocks_hourly_diff_ln ~ (1 + season_intraday_hourly + tf2_hourly*morality_lag + (1 + season_intraday_hourly | day_count)), data = stocks60_outrm_moralityonly, REML = TRUE)

stocks60.model.lme.foundations.outrm <- lmer(stocks_hourly_diff_ln ~  (1 + season_intraday_hourly + tf2_hourly*(care_lag + fairness_lag + loyalty_lag + authority_lag + sanctity_lag) + ( 1 + season_intraday_hourly | day_count)), data = stocks60_outrm_moralityonly, REML = TRUE)

Anova(stocks60.model.lm, type="III", test="F")
Anova(stocks60.model.lm.foundations, type="III", test="F")
Anova(stocks60.model.lme.null, type="III", test="F")
Anova(stocks60.model.lme, type="III", test="F")
Anova(stocks60.model.lme.foundations, type="III", test="F")

anova(stocks60.model.lm, stocks60.model.lm.foundations)
anova(stocks60.model.lme.null, stocks60.model.lme, stocks60.model.lme.foundations)
Anova(stocks60.model.lm.outrm, type="III", test="F")
Anova(stocks60.model.lm.foundations.outrm, type="III", test="F")
Anova(stocks60.model.lme.null.outrm, type="III", test="F")
Anova(stocks60.model.lme.outrm, type="III", test="F")
Anova(stocks60.model.lme.foundations.outrm, type="III", test="F")

anova(stocks60.model.lm.outrm, stocks60.model.lm.foundations.outrm)
anova(stocks60.model.lme.null.outrm, stocks60.model.lme.outrm, stocks60.model.lme.foundations.outrm)

summ(stocks60.model.lm, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)
summ(stocks60.model.lme, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)

summ(stocks60.model.lm.outrm, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)
summ(stocks60.model.lme.outrm, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)

summ(stocks60.model.lm.foundations, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)
summ(stocks60.model.lme.foundations, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)

summ(stocks60.model.lm.foundations.outrm, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)
summ(stocks60.model.lme.foundations.outrm, scale=TRUE, transform.response=TRUE, confint=TRUE, digits=3)

plot1 <- interact_plot(stocks60.model.lm, pred = morality_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.outrm, pred = morality_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)

plot1 <- interact_plot(stocks60.model.lme, pred = morality_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lme.outrm, pred = morality_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)


plot1 <- interact_plot(stocks60.model.lm.foundations, pred = care_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.foundations.outrm, pred = care_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)

plot1 <- interact_plot(stocks60.model.lm.foundations, pred = fairness_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.foundations.outrm, pred = fairness_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)

plot1 <- interact_plot(stocks60.model.lm.foundations, pred = loyalty_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.foundations.outrm, pred = loyalty_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)

plot1 <- interact_plot(stocks60.model.lm.foundations, pred = authority_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.foundations.outrm, pred = authority_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)

plot1 <- interact_plot(stocks60.model.lm.foundations, pred = sanctity_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
plot2 <- interact_plot(stocks60.model.lm.foundations.outrm, pred = sanctity_lag, modx = tf2_hourly, plot.points = TRUE, linearity.check = FALSE) + ylim(-0.04,0.04)
gridExtra::grid.arrange(plot1, plot2, ncol=2)
