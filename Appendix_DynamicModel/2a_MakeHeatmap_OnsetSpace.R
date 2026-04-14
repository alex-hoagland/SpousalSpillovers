# Make welfare heatmap (day of coinsurance onset space)


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

load("C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\AllCounterfactuals_202509.RData")

## ---------- shared setup (done once and works for both groups) ----------
N <- 5000 # how many individuals to sample
T <- 100 # how many periods
simdata <- expand_grid(
  id = 1:N,
  t = 1:100
) %>%
  arrange(id, t) %>% 
  mutate(eps_k = revd(n = (100*N), scale=1), 
         eps_d = revd(n = (100*N), scale=1)) 

tgrid <- 1:T

lambda_poly <- function(b0,b1,b2,b3,t) b0 + b1*t + b2*t^2 + b3*t^3
lambda_c_vec <- lambda_poly(l0_c, l1_c, l2_c, l3_c, tgrid)
lambda_t_vec <- lambda_poly(l0_t, l1_t, l2_t, l3_t, tgrid)

# Split simdata once so we don't filter repeatedly inside maps
persons <- simdata %>% arrange(id, t) %>% group_split(id, .keep = FALSE)

gov_paid <- function(exit_day, onset_day) {
  early <- pmin(exit_day, onset_day)
  late  <- pmax(exit_day - onset_day, 0L)
  187.50 * early + 187.50 * 0.8 * late
}

frac_c <- 1-0.27 # from KFF, about 27% of Medicare enrollees live alone

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

## ---------- total welfare given two onset days ----------
tot_utility <- function(onset_t, onset_c) { 
  # do the simulation for both groups given these onset days 
  p_base <- ifelse(tgrid < onset_t, 1e-5, 187.50)
  u     <- lambda_t_vec + alpha_t * p_base * 0.2
  omega <- omega_t
  scale <- sp_treated[7]
  shift <- shift_t
  res_t <- furrr::future_map(
    persons,
    simulate_one,
    u = u, omega = omega, scale = scale, shift = shift,
    .options = furrr::furrr_options(seed = TRUE)
  )
  
  p_base <- ifelse(tgrid < onset_c, 1e-5, 187.50)
  u     <- lambda_c_vec + alpha_c * p_base * 0.2
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
  df_t <- tibble::as_tibble(do.call(rbind, res_t)) %>% mutate(value = value/0.009) %>% 
    mutate(costs = 187.50*pmin(exit_day, onset_t) + 187.50*0.8*pmax(exit_day-onset_t,0))
  df_c <- tibble::as_tibble(do.call(rbind, res_c)) %>% mutate(value = value/0.097) %>% 
    mutate(costs = 187.50*pmin(exit_day, onset_c) + 187.50*0.8*pmax(exit_day-onset_c,0))
  rbind(df_t, df_c) %>% summarize(value = sum(value), costs = sum(costs)) %>% mutate(x = value - costs) %>% pull(x)
  # net social welfare
}
################################################################################


##### 1. Calculate welfare for each possible point in 2D space ################################
xseq <- seq(10, 50, by=10) # potential days of onset
yseq <- seq(10, 50, by=10) # potential days of onset

# find welfare for each point in (xseq, yseq) using tot_utitilty function
welfare <- data.frame(x = numeric(0), y = numeric(0), z = numeric(0))
for (i in seq_along(xseq)) {
  for (j in seq_along(yseq)) {
    w <- tot_utility(xseq[i], yseq[j])
    welfare <- rbind(welfare, data.frame(x = xseq[i], y = yseq[j], z = w))
    if (j == 1) { 
    cat("Completed (", xseq[i], ",", yseq[j], ") with welfare ", w, "\n")
    }
  }
}

base <- welfare %>% filter(x == 20, y == 20) %>% pull(z)
welfare_onset <- welfare %>% mutate(z = (z-base)/base)

govspend_c_seq_df <- data.frame(
  x = seq(from=10, to=50, by=1),
  govspend_c_seq
)

bline1 <- govspend_c_seq_df %>% filter(x %in% seq(10, 50, by=10))

welfare_onset <- welfare_onset %>% left_join(bline1, by="x") %>% 
  mutate(x1 = 20, x2 = 20)

# make a heatmap (need to set by=1 above everywhere to replicate this)
# toexport <- welfare_onset %>%
#   ggplot(aes(x = x, y = y, fill = z)) +
#   geom_tile() +
#   scale_fill_viridis_c() +
#   geom_smooth(aes(x=x, y = control_rate), color="black", size=2) +
#   geom_point(aes(x=x1,y=x2), color="red", size=2.5) +
#   labs(
#     x = "Sick Spouse Cost Sharing Onset (Day)", 
#     y = "Healthy Spouse Cost Sharing Onset (Day)", 
#     fill = "Welfare Change"
#   ) +
#   theme_minimal()

# skimmed down version
toexport <- welfare_onset %>%
  ggplot(aes(x = x, y = y)) +
  geom_tile(aes(fill = z), colour = "grey95", linewidth = 0.15) +  # thin gridlines help readability
  scale_fill_gradient(low="grey35",high="white") + 
  geom_smooth(aes(x = x, y = govspend_c_seq), color = "black", linewidth = 2) +
  geom_point(aes(x = x1, y = x2), color = "red", size = 2.5) +
  labs(
    x = "Sick Spouse Cost Sharing Onset (Day)", 
    y = "Healthy Spouse Cost Sharing Onset (Day)",
    fill = "Welfare Increase"
  ) + 
  theme_minimal()

ggsave(plot=toexport,
       "C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\Heatmap_OnsetSpace_20251113.png",
       width=6, height=4)
save.image("C:\\Users\\alexh\\Dropbox\\Spouses in Medicare\\Model\\Heatmap_OnsetSpace_Data.RData")
################################################################################
