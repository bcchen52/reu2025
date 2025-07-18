#include <math.h>

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