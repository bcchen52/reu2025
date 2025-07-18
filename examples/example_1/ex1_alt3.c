#include <math.h>

double code(double x) {
	return fma(0.5, x, (1.0 - sqrt(x)));
}