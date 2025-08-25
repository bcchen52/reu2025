#include <math.h>
#include <float.h>
#include <stdlib.h>
#include <stdio.h>

double gelu(double x0){
    double c = 0.7978845608028654;
    return 0.5 * x0 * (1.0 + tanh(c * (x0 + 0.044715 * (x0 * x0 * x0))));
}
