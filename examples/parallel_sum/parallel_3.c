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

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    double x = atof(argv[1]);
    printf("%.17e\n", parallel_sum3(x));
    return 0;
}
