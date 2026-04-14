#include <Rcpp.h>
#include <cmath>
using namespace Rcpp;

// forward–declare your existing solver
int simulate_person_value_cpp(NumericVector u,
                        NumericVector eps_d,
                        NumericVector eps_k,
                        double omega);

// [[Rcpp::export]]
IntegerVector simulate_all_value_cpp(IntegerVector id,
                               NumericVector u,
                               NumericVector eps_d,
                               NumericVector eps_k,
                               NumericVector omega) {
  // 1) figure out the unique ids
  IntegerVector uniq = sort_unique(id);
  int nIDs = uniq.size();
  int N    = id.size();
  
  IntegerVector out(nIDs);
  // 2) for each unique person
  for (int i = 0; i < nIDs; ++i) {
    int this_id = uniq[i];
    
    // collect only that person's shocks
    std::vector<double> u_sub, d_sub, k_sub, o_sub;
    u_sub.reserve(100);  // if you expect ~100
    d_sub.reserve(100);
    k_sub.reserve(100);
    o_sub.reserve(100);
    
    for (int j = 0; j < N; ++j) {
      if (id[j] == this_id) {
        u_sub.push_back(u[j]);
        d_sub.push_back(eps_d[j]);
        k_sub.push_back(eps_k[j]);
        o_sub.push_back(omega[j]);
      }
    }
    
    // convert back to R types
    NumericVector u_tmp    = wrap(u_sub);
    NumericVector eps_d_tmp= wrap(d_sub);
    NumericVector eps_k_tmp= wrap(k_sub);
    double     om          = o_sub.at(0);  // assume omega is constant per id
    
    // 3) call your solver
    out[i] = simulate_person_value_cpp(u_tmp, eps_d_tmp, eps_k_tmp, om);
  }
  
  // name the result by ID if you like
  out.attr("names") = uniq;
  return out;
}

// [[Rcpp::export]]
int simulate_person_value_cpp(NumericVector u, NumericVector eps_d, NumericVector eps_k, double omega) {
  int n = u.size(); // Expected to be 100
  // Rcpp::Rcout << "DEBUG: u.size() == " << n << std::endl;
  if (n <= 0) {
    Rcpp::stop("simulate_person_cpp: got a zero‑length u vector");
  }
  NumericVector EV(n);
  NumericVector V(n);
  NumericVector cumV(n);
  
  // Initialize EV: set the last period equal to omega.
  EV[n - 1] = omega;
  
  // Backward loop to compute EV for periods n-1 to 1.
  for (int d = n - 2; d >= 0; d--) {
    // EV[d] = u[d+1] + log(exp(EV[d+1]) + 1)
    EV[d] = u[d + 1] + log(exp(EV[d + 1]) + 1.0);
  }
  
  // Initialize V at the last period.
  V[n - 1] = u[n - 1];
  
  // Backward loop to compute V for periods n-1 to 1.
  for (int d = n - 2; d >= 0; d--) {
    // Compute the maximum between eps_k[d] + EV[d+1] and eps_d[d]
    double candidate1 = eps_k[d] + EV[d + 1];
    double candidate2 = eps_d[d];
    double max_candidate = (candidate1 > candidate2) ? candidate1 : candidate2;
    V[d] = u[d] + max_candidate;
  }
  
  // Compute the cumulative sum of V.
  cumV[0] = V[0];
  for (int d = 1; d < n; d++) {
    cumV[d] = cumV[d - 1] + V[d];
  }
  
  // Determine the maximum cumulative value.
  double max_val = cumV[0];
  for (int d = 1; d < n; d++) {
    if (cumV[d] > max_val) {
      max_val = cumV[d];
    }
  }
  
  return max_val; 
}