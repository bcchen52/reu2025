#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/**
 * @brief Unstable (naive) double-precision softmax function.
 * * This version calculates the softmax directly without subtracting the maximum
 * value from the inputs first. This makes it prone to numerical overflow when
 * inputs are large positive numbers and underflow when inputs are large
 * negative numbers.
 * * @param x0 The first input logit.
 * @param x1 The second input logit.
 * @param x2 The third input logit.
 * @return The softmax probability for x0.
 */
double softmax_x0_unstable_double(double x0, double x1, double x2) {
    // Directly calculate exponentials, which can lead to overflow/underflow
    double exp0 = exp(x0);
    double exp1 = exp(x1);
    double exp2 = exp(x2);
    return exp0 / (exp0 + exp1 + exp2);
}

/**
 * @brief Main function to read inputs and compute the unstable softmax.
 * * This program reads three double-precision floating-point numbers from
 * standard input, calculates the unstable softmax for the first value,
 * and prints the result to standard output with high precision.
 */
int main() {
    double x0, x1, x2;

    // Read three doubles from standard input, separated by spaces
    if (scanf("%lf %lf %lf", &x0, &x1, &x2) == 3) {
        // Call the unstable version of the function
        double result_value = softmax_x0_unstable_double(x0, x1, x2);
        
        // Print the result to standard output for the Python script to capture
        printf("%.17g\n", result_value);
        
        return 0; // Success
    } else {
        // If scanf fails (e.g., incorrect input format), exit with an error
        fprintf(stderr, "Error: Failed to read three double values from stdin.\n");
        return 1; 
    }
}
