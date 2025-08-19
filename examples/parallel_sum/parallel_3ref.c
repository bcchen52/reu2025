#include <stdio.h>
#include <stdlib.h>

double parallel_sum3(double x) {
    double v0 = x, v1 = x, v2 = x, v3 = x;
    double v4 = x, v5 = x, v6 = x, v7 = x;
    // level 1
    v0 += v1;  v2 += v3;  v4 += v5;  v6 += v7;
    // level 2
    v0 += v2;  v4 += v6;
    // level 3
    v0 += v4;
    return v0;
}
int main() {
    double x;

    // Read one double value from standard input
    if (scanf("%lf", &x) == 1) {
        // If successful, call the function and print the result
        printf("%.17e\n", parallel_sum3(x));
        return 0; // Success
    } else {
        // If scanf fails, print an error and exit
        fprintf(stderr, "Error: Failed to read a double value from input.\n");
        return 1; // Failure
    }
}