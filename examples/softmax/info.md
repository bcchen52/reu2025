The soft max function takes 3 inputs $x_0$, $x_1$, $x_2$, and puts and builds a probability distribution, where 


$$P(X_i) = \dfrac{e^{x_i}}{e^{x_1} + e^{x_2} + e^{x_3}}.$$

Different inputs...
- softmax1.cire might have some decent rounding
- softmax2.cire looking at a larger range
- softmax3.cire looking at larger negatives
- softmax4.cire lookats at a mix of scale

