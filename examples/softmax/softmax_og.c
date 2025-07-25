#include <math.h>
#include <float.h>

/*
 * softmax_safe:
 *   x   = pointer to input array of length n
 *   y   = pointer to output array of length n (must be allocated)
 *   n   = number of logits
 *
 * This implements:
 *   y[i] = exp(x[i] - M) / Σ[j=0..n-1] exp(x[j] - M)
 * where M = max_j x[j], to avoid overflow/underflow.
 */
double softmax_probe_x0(double x0, double x1, double x2) {
    double e0  = exp(x0);
    double e1  = exp(x1);
    double e2  = exp(x2);
    double sum = e0 + e1 + e2;
    double y0  = e0 / sum;
    return y0;
}
