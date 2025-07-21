#include <math.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

double code(double x) {
	return fma(0.5, x, (1.0 - sqrt(x)));
}

int main(int argc, char **argv){
	double x = atof(argv[1]);

	double result = code(x);

	printf("x = %.17e, sqrt(x) = %.17e\n", x, result);

	return 0;
}