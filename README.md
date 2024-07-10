# heegner-cones

Sage code to compute cones of Heegner divisors.

Requires 'weilrep' from github.com/btw-47/weilrep.


Example usage:

```
w = WeilRep([[2]])
k = 21/2
C = primitive_heegner_cone(w, k); C
```
