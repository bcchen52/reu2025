#include <math.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

float code(float x) {
	return 1.0f / (sqrtf(x) + sqrtf((1.0f + x)));
}

int main(int argc, char **argv){
	float x = atof(argv[1]);

	float result = code(x);

	printf("x = %.17e, sqrt(x) = %.17e\n", x, result);

	return 0;
}