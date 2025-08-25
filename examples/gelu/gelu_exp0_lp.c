#include <math.h>
#include <float.h>
#include <stdlib.h>
#include <stdio.h>

float gelu(float x0){
    float c = 0.7978845608028654f;
    return x0 / (1.0f + expf(-2.0f * c * (x0 + 0.044715f * x0*x0*x0)));
}
