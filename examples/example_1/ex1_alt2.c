#include <math.h>

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