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

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    double x = atof(argv[1]);
    printf("%f\n", parallel_sum2(x));
    return 0;
}
