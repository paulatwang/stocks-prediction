knitr::opts_chunk$set(echo = TRUE, collapse = FALSE, warning = FALSE, tidy = TRUE)
options(width=120)

setwd("~/Projects/mfstocks/rmd/60min") # data path
stocks60 <- read.table("processed_data/stocks60.csv", header=TRUE, stringsAsFactors=TRUE, sep=",", na.strings="NA", dec=".", strip.white=TRUE)
stocks60$dt_60 <- as.POSIXct(stocks60$dt_60, tz="EST") # CONVERT DT TO POSIX
col60 <- c("season_workday_60", "season_month_60", "tf2_60") 
stocks60[col60] <- lapply(stocks60[col60], as.factor) # CONVERT CAT VARs TO FACTORs

library(ggplot2) # plotting
library(gridExtra) #gridExtra
library(ggpubr)
theme_set(theme_pubclean())

stocks60 %>% colnames()


# Stocks
hist(stocks60[,c(6, 19, 20)])

# Morality 
hist(stocks60[, c(18, 33, 34)])

# Foundation probabilities*sentiments
hist(stocks60[28:32]) 
hist(stocks60[35:39]) # lags
hist(stocks60[40:44]) # leads

stocks60 %>% colnames()

# Morality

png("figs/boxplot_morality.png", width = 8, height=5, units='in', res=300)
ggplot(stocks60 %>% na.omit(), aes(x = tf2_60, y = morality_lag)) +   
  geom_violin(trim = FALSE, fill = "lightblue", color = "lightblue") +
  geom_boxplot(notch = TRUE, fill = "white", color =c("#00AFBB","#E7B800")) +
  stat_summary(fun = mean, geom = "point",shape = 18, size = 2.5, color = "#FC4E07") + # identify mean
  labs(x="Economic Period", y = "Morality Score") + 
  scale_x_discrete(labels=c("High","Low"))
dev.off()

# Foundations
  stocks60_foundations_long = melt(stocks60[, c(17,22:26)], id.vars=c("tf2_60")) 

png("figs/boxplot_foundations.png", width = 8, height=5, units='in', res=300)
ggplot(stocks60_foundations_long%>% na.omit(), aes(x = variable, y = value))  +
  geom_violin(trim = FALSE, position = position_dodge(0.9), fill = "lightblue", color = "lightblue") +   
  stat_summary(fun = mean, geom = "point",shape = 18, size = 2.5, color = "#FC4E07") + # identify mean
  geom_boxplot(aes(color = tf2_60), width = 0.60, position = position_dodge(0.9)) + 
  scale_color_manual(labels = c("High", "Low"), values = c("#00AFBB","#E7B800")) + 
  scale_x_discrete(labels=c("Care","Fairness","Loyalty","Authority", "Sanctity")) +
  theme(legend.position="right") + 
  labs(x="Moral Foundations", y = "Foundation Score",colour="Economic Period")
dev.off()


# SCATTERPLOT
plot_scatter <- function(input, x_label) {
  return(ggplot(stocks60, aes(input, stocks_60_diff_ln, color=tf2_60)) + 
           geom_point() + 
           geom_smooth(method=lm) +
           scale_color_manual(labels = c("High", "Low"), values = c('#00AFBB','#E7B800')) + 
           theme(legend.position=c(0,1), legend.justification=c(0,1)) + 
    labs(x=x_label, y = "Market Movement", color = "Economic Period")
         )}

# X DENSITY
plot_xdensity <- function(input) {
  return(ggplot(stocks60, aes(input, fill=tf2_60)) +
           geom_density(alpha=.5) +
           scale_fill_manual(values = c('#00AFBB','#E7B800')) + 
           theme(legend.position = "none")  + 
    labs(x = "") )}

# Y DENSITY
plot_ydensity <- function() {
  return(ggplot(stocks60, aes(stocks_60_diff_ln, fill=tf2_60)) +
           geom_density(alpha=.5) +
           scale_fill_manual(values = c('#00AFBB','#E7B800')) +
           theme(legend.position = "none")  + 
    labs(x = "") )}

width=8
height=5

png("figs/scatter_morality.png", width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$morality_lag, "Morality")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$morality_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # MORALITY PLOT
dev.off()

png("figs/scatter_care.png", width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$care_lag, "Care")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$care_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # CARE PLOT
dev.off()


png("figs/scatter_fairness.png", width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$fairness_lag, "Fairness")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$fairness_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # FAIRNESS PLOT
dev.off()


png("figs/scatter_loyalty.png", width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$loyalty_lag, "Loyalty")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$loyalty_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # LOYALTY PLOT
dev.off()


png("figs/scatter_authority.png",width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$authority_lag, "Authority")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$authority_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # AUTHORITY PLOT
dev.off()

png("figs/scatter_sanctity.png", width = width, height=height, units='in', res=300)
scatterPlot <- plot_scatter(stocks60$sanctity_lag, "Sanctity")
scatterPlot2 <- scatterPlot + theme(legend.position = "none")
xdensity <- plot_xdensity(stocks60$sanctity_lag)
ydensity <- plot_ydensity() + coord_flip()
legend <- get_legend(scatterPlot)
grid.arrange(xdensity, legend, scatterPlot2, ydensity, ncol=2, nrow=2, widths=c(4, 1.4), heights=c(1.4, 4)) # SANCTITY PLOT           
dev.off()
