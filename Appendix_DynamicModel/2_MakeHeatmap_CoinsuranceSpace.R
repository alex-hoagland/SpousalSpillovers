# Make heatmap figures (coinsurance rate space)


###### Data setup ##############################################################
set.seed(20250212) # set seed for random draws

library(tidyverse) # call the relevant library
library(EnvStats) # for type 1 distribution
library(purrr) # for parallelizing
library(furrr) # for parallelizing
library(Rcpp) # for CS loops (to go faster?)
library(future)
library(parallel)
plan(multisession, workers = detectCores()-1)

# load("C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\AllCounterfactuals_202509_coinsurance.RData")
load("C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\working.RData")

## ---------- shared setup (done once and works for both groups) ----------

N <- 5000 # how many individuals to sample (for the colors can be 1000, but needs to be 10000 or so to get the budget lines right)
T <- 100 # how many periods
simdata <- expand_grid(
  id = 1:N,
  t = 1:100
) %>%
  arrange(id, t) %>% 
  mutate(eps_k = revd(n = (100*N), scale=1), 
         eps_d = revd(n = (100*N), scale=1)) 

tgrid <- 1:T
p_base <- ifelse(tgrid < 22, 1e-5, 187.50)

lambda_poly <- function(b0,b1,b2,b3,t) b0 + b1*t + b2*t^2 + b3*t^3
lambda_c_vec <- lambda_poly(l0_c, l1_c, l2_c, l3_c, tgrid)
lambda_t_vec <- lambda_poly(l0_t, l1_t, l2_t, l3_t, tgrid)

# Split simdata once so we don't filter repeatedly inside maps
persons <- simdata %>% arrange(id, t) %>% group_split(id, .keep = FALSE)

gov_paid <- function(exit_day, rate) {
  early <- pmin(exit_day, 20L)
  late  <- pmax(exit_day - 20L, 0L)
  187.50 * early + 187.50 * rate * late
}

frac_c <- 1-0.27 # from KFF, about 27% of Medicare enrollees live alone

avg_spend <- function(group, rate) { # group should be "treated" or "control"
  if (group == "treated") {
    u     <- lambda_t_vec + alpha_t * (p_base * (1 - rate))
    omega <- omega_t
    scale <- sp_treated[7]
    shift <- shift_t
  } else {
    u     <- lambda_c_vec + alpha_c * (p_base * (1 - rate))
    omega <- omega_c
    scale <- sp_control[7]
    shift <- shift_c
  }
  
  res <- furrr::future_map(
    persons,
    simulate_one,
    u = u, omega = omega, scale = scale, shift = shift,
    .options = furrr::furrr_options(seed = TRUE)
  )
  
  df <- tibble::as_tibble(do.call(rbind, res))
  mean(gov_paid(df$exit_day, rate))
}


## ---------- core simulator for one person ----------
simulate_one <- function(person_df, u, omega, scale, shift) {
  eps_d <- scale * person_df$eps_d
  eps_k <- scale * person_df$eps_k
  
  EV <- numeric(T); EV[T] <- omega
  for (d in (T-1):1) {
    EV[d] <- u[d + 1] + log1p(exp(EV[d + 1]))  # softplus
  }
  
  V <- numeric(T); V[T] <- u[T]
  for (d in (T-1):1) {
    V[d] <- u[d] + max(eps_k[d] + EV[d + 1], eps_d[d])
  }
  
  cumV <- cumsum(V) - shift
  if (cumV[1] >= 0) {
    exit_day <- which.max(cumV)
    value <- cumV[exit_day]
  } else {
    exit_day <- 0L; value <- 0
  }
  if (!is.finite(V[1])) exit_day <- T
  c(exit_day = exit_day, value = value)
}

## ---------- average welfare given two rates ----------
tot_utility <- function(rate_t, rate_c) { 
  # do the simulation for both groups given these rates 
  u     <- lambda_t_vec + alpha_t * (p_base * (1 - rate_t))
  omega <- omega_t
  scale <- sp_treated[7]
  shift <- shift_t
  res_t <- furrr::future_map(
    persons,
    simulate_one,
    u = u, omega = omega, scale = scale, shift = shift,
    .options = furrr::furrr_options(seed = TRUE)
  )
  
  u     <- lambda_c_vec + alpha_c * (p_base * (1 - rate_c))
  omega <- omega_c
  scale <- sp_control[7]
  shift <- shift_c
  res_c <- furrr::future_map(
    persons,
    simulate_one,
    u = u, omega = omega, scale = scale, shift = shift,
    .options = furrr::furrr_options(seed = TRUE)
  )
  
  # find total utility
  df_t <- tibble::as_tibble(do.call(rbind, res_t)) %>% mutate(value = value/0.009)
  df_c <- tibble::as_tibble(do.call(rbind, res_c)) %>% mutate(value = value/0.097)
  cs <- rbind(df_t, df_c) %>% summarize(value = sum(value)) %>% pull(value)
  
  # net social welfare
  # df_t <- tibble::as_tibble(do.call(rbind, res_t)) %>% mutate(value = value/0.009) %>% 
  #   mutate(costs = 187.50*pmin(exit_day, 21) + 187.50*rate_t*pmax(exit_day-21,0))
  # df_c <- tibble::as_tibble(do.call(rbind, res_c)) %>% mutate(value = value/0.097) %>% 
  #   mutate(costs = 187.50*pmin(exit_day, 21) + 187.50*rate_c*pmax(exit_day-21,0))
  # rbind(df_t, df_c) %>% summarize(value = sum(value), costs = sum(costs)) %>% mutate(x = value - costs) %>% pull(x)
  
  paid_t <- mean(gov_paid(df_t$exit_day, rate_t))
  paid_c <- mean(gov_paid(df_c$exit_day, rate_c))
  paid <- (frac_c * paid_c + (1-frac_c) * paid_t)
  return(c(cs, paid))
}

# find control coinsurance that hits the target; try root, fall back to squared-loss
find_control_rate <- function(target) {
  f <- function(z) avg_spend("control", z) - target
  f0 <- f(0); f1 <- f(1)
  if (is.finite(f0) && is.finite(f1) && sign(f0) != sign(f1)) {
    uniroot(f, c(0, 1), tol = 1e-3)$root
  } else {
    optimize(function(z) f(z)^2, c(0, 1))$minimum
  }
}
################################################################################


##### 1. Budget neutral line, coinsurance space ################################
xseq <- seq(0.5, 1, by=0.1) # subsidization rates for treated group ( = 1 - coinsurance)
yseq <- seq(0.5, 1, by=0.1) # subsidization rates for control group ( = 1 - coinsurance)

# find welfare for each point in (xseq, yseq) using tot_utitilty function
welfare <- data.frame(x = numeric(0), y = numeric(0), z = numeric(0), costs = numeric(0))
for (i in seq_along(xseq)) {
  for (j in seq_along(yseq)) {
    u <- tot_utility(xseq[i], yseq[j])
    welfare <- rbind(welfare, data.frame(x = xseq[i], y = yseq[j], z = u[1], costs = u[2]))
    if (j == 1) { 
      cat("Completed (", xseq[i], ",", yseq[j], ") with welfare ", u[1], " and costs ", u[2], "\n")
    }
  }
}

base <- welfare %>% filter(x == 0.8, y == 0.8) %>% pull(z)
welfare_onset <- welfare %>% mutate(z = z/base) # %>% mutate(z = z/abs(base))

govspend_c_seq_df <- data.frame(
  x = seq(0.5, 1, by=0.01),
  govspend_c_seq
)

bline1 <- govspend_c_seq_df %>% filter(x %in% seq(0.5, 1, by=0.1))

welfare_onset <- welfare_onset %>% left_join(bline1, by="x") %>%
  mutate(x1 = 0.8, x2 = 0.8)

# make a heatmap 
# toexport <- welfare_onset %>%
#   ggplot(aes(x = x, y = y)) +
#   geom_tile(aes(fill=z)) +
#   scale_fill_viridis_c() +
#   geom_smooth(aes(x=x, y = control_rate), color="black", size=2) +
#   geom_point(aes(x=x1,y=x2), color="red", size=2.5) +
#   labs(
#     x = "Sick Spouse Subsidization (%)", 
#     y = "Healthy Spouse Subsidization (%)", 
#     fill = "Welfare Change"
#   ) +
#   theme_minimal()
# 
# library(ggplot2)

# Just one budget line
toexport <- welfare_onset %>%
  filter(x >= 0.5) %>% filter(y >= 0.5) %>%
  ggplot(aes(x = x, y = y)) +
  geom_tile(aes(fill = z), colour = "grey95", linewidth = 0.15) +  # thin gridlines help readability
  scale_fill_gradient(low="grey35",high="white") + 
  geom_smooth(aes(x = x, y = govspend_c_seq), color = "black", linewidth = 2) +
  geom_point(aes(x = x1, y = x2), color = "red", size = 2.5) +
  labs(
    x = "Sick Spouse Subsidization (%)",
    y = "Healthy Spouse Subsidization (%)",
    fill = "Welfare Increase"
  ) + 
  theme_minimal()

# # Just one budget line
# welfare_onset %>%
#   ggplot(aes(x = x, y = y)) +
#   geom_tile(aes(fill = z), colour = "grey90", linewidth = 0.15) +  # thin gridlines help readability
#   scale_fill_viridis_b(
#     n.breaks = 11,                      # try 5–9
#     guide = guide_colorsteps()         # stepped legend
#   ) +
#   geom_smooth(aes(x = x, y = control_rate), color = "black", linewidth = 2) +
#   geom_point(aes(x = x1, y = x2), color = "red", size = 2.5) +
#   labs(
#     x = "Sick Spouse Subsidization (%)",
#     y = "Healthy Spouse Subsidization (%)",
#     fill = "Welfare Increase"
#   ) + 
#   theme_minimal()
# 
# # Now add a few more isoquants
#   govspend_t_seq <- vapply(seq(0.0, 1, by=0.02), function(x) avg_spend("treated", x), numeric(1))
#   
#   # budget-neutral target for control side
#   govspend_y <- (pre_spend - (1 - frac_c) * govspend_t_seq) / frac_c
#   
#   # Add 4 lines for different budget targets
#   target1 <- (pre_spend*0.4 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target2 <- (pre_spend*0.5 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target3 <- (pre_spend*0.6 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target4 <- (pre_spend*0.7 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target5 <- (pre_spend*0.8 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target6 <- (pre_spend*0.9 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target7 <- (pre_spend*1 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target8 <- (pre_spend*1.1 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target9 <- (pre_spend*1.2 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target10 <- (pre_spend*1.3 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target11 <- (pre_spend*1.4 - (1 - frac_c) * govspend_t_seq) / frac_c
#   target12 <- (pre_spend*1.5 - (1 - frac_c) * govspend_t_seq) / frac_c
#   
#   iq1 <- vapply(target1, find_control_rate, numeric(1))
#   iq2 <- vapply(target2, find_control_rate, numeric(1))
#   iq3 <- vapply(target3, find_control_rate, numeric(1))
#   iq4 <- vapply(target4, find_control_rate, numeric(1))
#   iq5 <- vapply(target5, find_control_rate, numeric(1))
#   iq6 <- vapply(target6, find_control_rate, numeric(1))
#   iq7 <- vapply(target7, find_control_rate, numeric(1))
#   iq8 <- vapply(target8, find_control_rate, numeric(1))
#   iq9 <- vapply(target9, find_control_rate, numeric(1))
#   iq10 <- vapply(target10, find_control_rate, numeric(1))
#   iq11 <- vapply(target11, find_control_rate, numeric(1))
#   iq12 <- vapply(target12, find_control_rate, numeric(1))
#   
#   bline <- data.frame(
#     x = seq(0.0, 1, by=0.02),
#     iq1 = iq1,
#     iq2 = iq2,
#     iq3 = iq3,
#     iq4 = iq4,
#     iq5 = iq5,
#     iq6 = iq6,
#     iq7 = iq7,
#     iq8 = iq8,
#     iq9 = iq9,
#     iq10 = iq10,
#     iq11 = iq11,
#     iq12 = iq12)
#     
# toexport <- welfare_onset %>% select(-c("control_rate")) %>% left_join(bline, by="x") %>%
#   ggplot(aes(x = x, y = y)) +
#   geom_tile(aes(fill = z), colour = "grey90", linewidth = 0.15) +  # thin gridlines help readability
#   scale_fill_viridis_b(
#     n.breaks = 9,                      # try 5–9
#     guide = guide_colorsteps()         # stepped legend
#   ) +
#   geom_smooth(aes(x = x, y = iq7), color = "black", linewidth = 2) +
#   geom_smooth(aes(x = x, y = iq2), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq3), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq4), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq6), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq1), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq8), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq9), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq10), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq11), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_smooth(aes(x = x, y = iq12), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed") +
#   geom_point(aes(x = x1, y = x2), color = "red", size = 2.5) +
#   labs(
#     x = "Sick Spouse Subsidization (%)",
#     y = "Healthy Spouse Subsidization (%)",
#     fill = "Welfare Increase"
#   ) +
#   theme_minimal()
# 
# # where the budget curve falls below 0, take those points out so that the smoothing can work well
# # just doing this manually
# toexport <- welfare_onset %>% select(-c("control_rate")) %>% left_join(bline, by="x") %>%
#   mutate(iq1 = ifelse(x > 0.48, NA, iq1),
#          iq2 = ifelse(x > 0.78, NA, iq2),
#          iq3 = ifelse(x > 0.96, NA, iq3)) %>%
#   ggplot(aes(x = x, y = y)) +
#   geom_tile(aes(fill = z), colour = "grey90", linewidth = 0.15) +  # thin gridlines help readability
#   scale_fill_viridis_b(
#     n.breaks = 9,                      # try 5–9
#     guide = guide_colorsteps()         # stepped legend
#   ) +
#   geom_smooth(aes(x = x, y = iq7), color = "black", linewidth = 2) +
#   geom_smooth(aes(x = x, y = iq2), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq3), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq4), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq6), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq1), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq8), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq9), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq10), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq11), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_smooth(aes(x = x, y = iq12), color = "white", alpha=0.8, linewidth = 1, linetype = "dashed", se = FALSE) +
#   geom_point(aes(x = x1, y = x2), color = "red", size = 2.5) +
#   labs(
#     x = "Sick Spouse Subsidization (%)",
#     y = "Healthy Spouse Subsidization (%)",
#     fill = "Welfare Increase"
#   ) +
#   theme_minimal() + scale_y_continuous(limits = c(0,1))


ggsave(plot=toexport,
       "C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\Heatmap_CoinsuranceSpace_20251113.png",
       width=6, height=4)
save.image("C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\Heatmap_CoinsuranceSpace_Data.RData")
################################################################################
