#include <math.h>
#include <float.h>
#include <stdlib.h>
#include <stdio.h>

double gelu(double x0){
    double c = 0.7978845608028654;
    return x0 / (1.0 + exp(-2.0 * c * (x0 + 0.044715 * x0*x0*x0)));
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    double x = atof(argv[1]);
    printf("%.17e\n", gelu(x));
    return 0;
}