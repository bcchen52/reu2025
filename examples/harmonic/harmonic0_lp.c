#include <math.h>
#include <float.h>
#include <stdlib.h>
#include <stdio.h>

float harmonic(float x0, float x1){
    return (2*x0*x1)/(x0+x1);
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <value1> <value2>\n", argv[0]);
        return 1;
    }
    float x0 = atof(argv[1]);
    float x1 = atof(argv[2]);
    printf("%.17e\n", harmonic(x0, x1));
    return 0;
}