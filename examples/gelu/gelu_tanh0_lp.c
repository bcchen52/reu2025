#include <math.h>
#include <float.h>
#include <stdlib.h>
#include <stdio.h>

float gelu(float x0){
    float c = 0.7978845608028654f;
    return 0.5f * x0 * (1.0f + tanhf(c * (x0 + 0.044715f * (x0 * x0 * x0))));
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <value>\n", argv[0]);
        return 1;
    }
    float x = atof(argv[1]);
    printf("%.17e\n", gelu(x));
    return 0;
}