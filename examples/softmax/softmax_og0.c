#include <math.h>
#include <float.h>
#include <stdio.h>
#include <stdlib.h>

double softmax_x0(double x0, double x1, double x2) {
    return exp(x0) / (exp(x0) + exp(x1) + exp(x2));
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <x0> <x1> <x2>\n", argv[0]);
        return 1;
    }

    /* Parse three logits from the command line */
    double x0 = atof(argv[1]);
    double x1 = atof(argv[2]);
    double x2 = atof(argv[3]);

    /* Call your softmax, which returns only y0 */
    double y0 = softmax_x0(x0, x1, x2);

    /* Print the single output */
    printf("softmax(%g, %g, %g) = %g\n", x0, x1, x2, y0);

    return 0;
}
