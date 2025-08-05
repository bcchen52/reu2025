#include <stdio.h>
#include <stdlib.h>

double parallel_sum2(double x) {
    double v0 = x;
    double v1 = x;
    double v2 = x;
    double v3 = x;
    // level 1
    v0 += v1;
    v2 += v3;
    // level 2
    v0 += v2;
    return v0;
}

int main() {
    double x;

    // Read one double value from standard input
    if (scanf("%lf", &x) == 1) {
        // If successful, call the function and print the result
        printf("%.17e\n", parallel_sum2(x));
        return 0; // Success
    } else {
        // If scanf fails, print an error and exit
        fprintf(stderr, "Error: Failed to read a double value from input.\n");
        return 1; // Failure
    }
}