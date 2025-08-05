#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// High-precision double version of the function
double softmax_x0_stable_double(double x0, double x1, double x2) {
    double max_val = fmax(x0, fmax(x1, x2));
    double exp0 = exp(x0 - max_val);
    double exp1 = exp(x1 - max_val);
    double exp2 = exp(x2 - max_val);
    return exp0 / (exp0 + exp1 + exp2);
}

// Main function that reads from standard input
int main() {
    double x0, x1, x2;

    // Read three doubles from standard input
    if (scanf("%lf %lf %lf", &x0, &x1, &x2) == 3) {
        double true_value = softmax_x0_stable_double(x0, x1, x2);
        // Print result to standard output for Python to capture
        printf("%.17g\n", true_value);
        return 0; // Success
    } else {
        // If scanf fails, exit with an error
        return 1; 
    }
}