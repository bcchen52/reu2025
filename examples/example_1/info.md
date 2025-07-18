Example 1 is $\sqrt{x + 1} - \sqrt{x}$

lp stands for low precision and uses and outputs float, 32fp, while no suffix uses double, 64fp.

Alternatives 1 and 2 have higher accuracy and lower speed.

Alternative 1 is $\dfrac{1}{\sqrt{1}+\sqrt{1+x}}$.

Alternative 2 is $t_0 = \sqrt{x + 1} - \sqrt{x}$, if $t_0 \leq 4 \cdot 10^{-5}$, $t_0 = \sqrt{x^{-1}} \cdot 0.5$

Alternatives 3 and 4 have significantly lower accuracy but are faster.

Alternative 3 is $fma(0.5, x, 1- \sqrt{x})$

Alternative 4 is $1-\sqrt(x)$