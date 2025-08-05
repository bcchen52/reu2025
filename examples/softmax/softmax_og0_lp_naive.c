#include <math.h>
#include <float.h>
#include <stdio.h>
#include <stdlib.h>

// Function using float for calculations
float softmax_x0_float(float x0, float x1, float x2) {
    // Use expf() for float arguments
    return expf(x0) / (expf(x0) + expf(x1) + expf(x2));
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <x0> <x1> <x2>\n", argv[0]);
        return 1;
    }

    /* Parse three logits from the command line into floats */
    float x0 = atof(argv[1]);
    float x1 = atof(argv[2]);
    float x2 = atof(argv[3]);

    /* Call your softmax, which returns a float */
    float y0 = softmax_x0_float(x0, x1, x2);

    /* Print the single output */
    // Use %f or %g for printing floats
    printf("softmax(%f, %f, %f) = %f\n", x0, x1, x2, y0);

    return 0;
}