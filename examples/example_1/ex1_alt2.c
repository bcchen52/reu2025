#include <math.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

/*
double code(double x) {
	double t_0 = sqrt((x + 1.0)) - sqrt(x);
	double tmp;
	if (t_0 <= 4e-5) {
		tmp = sqrt(pow(x, -1.0)) * 0.5;
	} else {
		tmp = t_0;
	}
	return tmp;
}
*/

double code(double x) {
	return pow((sqrt(x) + 1.0), -1.0);
}

int main(int argc, char **argv){
	double x = atof(argv[1]);

	double result = code(x);

	printf("x = %.17e, sqrt(x) = %.17e\n", x, result);

	return 0;
}