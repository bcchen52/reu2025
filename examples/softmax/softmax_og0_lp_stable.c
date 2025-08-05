#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/**
 * @brief Calculates the first element of the softmax function in a 
 * numerically stable way.
 * * @param x0 The first logit.
 * @param x1 The second logit.
 * @param x2 The third logit.
 * @return The first element of the softmax output vector.
 */
float softmax_x0_stable(float x0, float x1, float x2) {
    // Find the maximum value among the inputs to prevent overflow
    float max_val = fmaxf(x0, fmaxf(x1, x2));
    
    // Subtract the max value from each input before exponentiating
    float exp0 = expf(x0 - max_val);
    float exp1 = expf(x1 - max_val);
    float exp2 = expf(x2 - max_val);
    
    // The result is mathematically identical but avoids large intermediate values
    return exp0 / (exp0 + exp1 + exp2);
}

int main(int argc, char **argv) {
    // Ensure the user provides exactly three numbers
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <x0> <x1> <x2>\n", argv[0]);
        return 1;
    }

    // Parse the three logits from the command line arguments
    float x0 = strtof(argv[1], NULL);
    float x1 = strtof(argv[2], NULL);
    float x2 = strtof(argv[3], NULL);

    // Call the stable softmax function
    float y0 = softmax_x0_stable(x0, x1, x2);

    // Print the result
    printf("stable_softmax(%g, %g, %g) = %g\n", x0, x1, x2, y0);

    return 0;
}
