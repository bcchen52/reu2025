#include <math.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

/*
float code(float x) {
	float t_0 = sqrtf((x + 1.0f)) - sqrtf(x);
	float tmp;
	if (t_0 <= 4e-5) {
		tmp = sqrtf(powf(x, -1.0f)) * 0.5f;
	} else {
		tmp = t_0;
	}
	return tmp;
}
*/

float code(float x) {
	return pow((sqrt(x) + 1.0), -1.0);
}

int main(int argc, char **argv){
	float x = atof(argv[1]);

	float result = code(x);

	printf("x = %.17e, sqrt(x) = %.17e\n", x, result);

	return 0;
}