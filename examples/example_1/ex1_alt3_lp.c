#include <math.h>

float code(float x) {
	return fma(0.5f, x, (1.0f - sqrtf(x)));
}