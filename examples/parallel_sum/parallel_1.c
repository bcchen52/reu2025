#include <stdio.h>
#include <stdlib.h>

double parallel_sum1(double x) {
    double v0 = x;
    double v1 = x;
    v0 += v1;
    return v0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    double x = atof(argv[1]);
    printf("%f\n", parallel_sum1(x));
    return 0;
}
