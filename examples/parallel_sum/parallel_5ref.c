#include <stdio.h>
#include <stdlib.h>

double parallel_sum5(double x) {
    double v0 = x,  v1 = x,  v2 = x,  v3 = x;
    double v4 = x,  v5 = x,  v6 = x,  v7 = x;
    double v8 = x,  v9 = x,  v10 = x, v11 = x;
    double v12 = x, v13 = x, v14 = x, v15 = x;
    double v16 = x, v17 = x, v18 = x, v19 = x;
    double v20 = x, v21 = x, v22 = x, v23 = x;
    double v24 = x, v25 = x, v26 = x, v27 = x;
    double v28 = x, v29 = x, v30 = x, v31 = x;
    // level 1
    v0  += v1;   v2  += v3;   v4  += v5;   v6  += v7;
    v8  += v9;   v10 += v11;  v12 += v13;  v14 += v15;
    v16 += v17;  v18 += v19;  v20 += v21;  v22 += v23;
    v24 += v25;  v26 += v27;  v28 += v29;  v30 += v31;
    // level 2
    v0  += v2;   v4  += v6;   v8  += v10;  v12 += v14;
    v16 += v18;  v20 += v22;  v24 += v26;  v28 += v30;
    // level 3
    v0  += v4;   v8  += v12;  v16 += v20;  v24 += v28;
    // level 4
    v0  += v8;   v16 += v24;
    // level 5
    v0  += v16;
    return v0;
}
int main() {
    double x;

    // Read one double value from standard input
    if (scanf("%lf", &x) == 1) {
        // If successful, call the function and print the result
        printf("%.17e\n", parallel_sum5(x));
        return 0; // Success
    } else {
        // If scanf fails, print an error and exit
        fprintf(stderr, "Error: Failed to read a double value from input.\n");
        return 1; // Failure
    }
}