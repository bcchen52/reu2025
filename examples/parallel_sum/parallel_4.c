#include <stdio.h>
#include <stdlib.h>

double parallel_sum4(double x) {
    double v0 = x,  v1 = x,  v2 = x,  v3 = x;
    double v4 = x,  v5 = x,  v6 = x,  v7 = x;
    double v8 = x,  v9 = x,  v10 = x, v11 = x;
    double v12 = x, v13 = x, v14 = x, v15 = x;
    // level 1
    v0  += v1;   v2  += v3;   v4  += v5;   v6  += v7;
    v8  += v9;   v10 += v11;  v12 += v13;  v14 += v15;
    // level 2
    v0  += v2;   v4  += v6;   v8  += v10;  v12 += v14;
    // level 3
    v0  += v4;   v8  += v12;
    // level 4
    v0  += v8;
    return v0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    double x = atof(argv[1]);
    printf("%f\n", parallel_sum4(x));
    return 0;
}
