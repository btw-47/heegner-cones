## Sage code to compute the cone of Heegner divisors.
## This requires the package weilrep from github.com/btw-47/weilrep, as well as the package PyNormaliz.

import math
import scipy

from collections import defaultdict

from PyNormaliz import Cone as NCone
from weilrep import *

def incircle_radius(vertices):
    r"""
    Given a list of vertices, compute the largest ball centered at 0 contained in their convex hull
    """
    p = Polyhedron(vertices).Hrepresentation()
    x = [abs(ieq.b()) / ieq.outer_normal().change_ring(RR).norm() for ieq in p]
    return min(x)

def heegner_divisor_iterator(w, max_discr = 1):
    r"""
    Iterate through Heegner divisors of discriminant up to a given bound (default 1).

    INPUT:
    - ``w`` -- a WeilRep
    - ``max_discr`` -- the bound for the discriminant

    OUTPUT: an iterator over tuples of the form (x_1,...,x_r, N), corresponding to the Heegner divisor H( (x_1,...,x_r) + ZZ^N, N).
    """
    w_dual = w.dual()
    rds = w_dual.sorted_rds()
    n = w_dual.norm_dict()
    m = 1
    while m <= ceil(max_discr):
        for g in rds:
            N = m + n[g]
            if N <= max_discr:
                yield tuple(list(g) + [N])
        m += 1

def primitive_heegner_divisor(w, g, _flag = 0):
    r"""
    Decompose a Heegner divisor (g) attached to the weilrep (w) into irreducible divisors.

    INPUT:
    - ``w`` -- a WeilRep
    - ``g`` -- a tuple
    """
    N = g[-1]
    h = heegner_divisor_iterator(w, max_discr = N / 4)
    x = [(1, g)]
    for y in h:
        m = isqrt(N // y[-1])
        if _flag == 1:
            moebius_m = 1
        else:
            moebius_m = moebius(m)
        if moebius_m:
            if y[-1] * (m * m) == N:
                if all(m * y[i] - v in ZZ for i, v in enumerate(g[:-1])):
                    x += [(moebius_m, y)]
                if all(m * y[i] + v in ZZ for i, v in enumerate(g[:-1])):
                    x += [(moebius_m, y)]
    return x

def coefficient_functional(X, heegner_divisor):
    r"""
    Represent a Heegner divisor as a functional on a space X of modular forms of dual weight (2 - k).
    """
    Y = [x.coefficients() for x in X]
    return vector([sum(n * y[g] for n, g in heegner_divisor) for y in Y])


def _special_basis(w, k, prec):
    r"""
    Compute a distinguished basis of cusp forms.
    """
    d = w.cusp_forms_dimension(k)
    if not d:
        return [], []
    nd = w.norm_dict()
    rds = w.sorted_rds()
    L = []
    M = []
    m = 1
    e = w.eisenstein_series(k, prec)
    while len(L) < d:
        for g in rds:
            index = m + nd[tuple(g)]
            f = w.pss(k, vector(g), index, prec)
            f1 = (f - e) / 2
            L1 = L + [f1]
            V = relations(L1)
            if not V.dimension():
                L = L1
                M = M + [index]
                if len(L) == d:
                    return L, M
        m += 1


def heegner_cone(w, k, bound = None, primitive = False, verbose = False, initial_bound = 2):
    r"""
    Compute the cone generated by the coefficient functionals attached to all Heegner divisors.
    """
    w_dual = w.dual()
    L, M = _special_basis(w_dual, k, ceil(initial_bound) + 1)
    e = w_dual.eisenstein_series(k, ceil(initial_bound) + 1)
    X = [e] + L
    if verbose:
        print('Computed all modular forms in the dual space.')
    h = heegner_divisor_iterator(w, max_discr = initial_bound)
    if bound is None:
        bound = _bound(w, k, e, L, M, primitive = primitive)
    try:
        bound = bound.n()
    except AttributeError:
        pass
    if verbose:
        print('Using the bound: %s'%bound)
    L, M = _special_basis(w_dual, k, ceil(bound) + 1)
    e = w_dual.eisenstein_series(k, ceil(bound) + 1)
    if primitive:
        C = ConeOfHeegnerDivisors(w, k, bound, [coefficient_functional(X, primitive_heegner_divisor(w, g)) for g in h], 'P', X = [e] + L)
    else:
        C = ConeOfHeegnerDivisors(w, k, bound, [coefficient_functional(X, [(1, g)]) for g in h], 'H', X = [e] + L)
    C.check(bound)
    return C

def primitive_heegner_cone(*_, bound = None, verbose = False, initial_bound = 2.0):
    return heegner_cone(*_, bound = bound, primitive = True, verbose = verbose, initial_bound = initial_bound)

def _radius_constant(w, k, e, L, M, primitive = False):
    r"""
    """
    b = max(ceil(k/12), max(M))
    if 12*b == k:
        b += 1
    h = heegner_divisor_iterator(w, max_discr = b)
    if primitive:
        vertices = [coefficient_functional(L, primitive_heegner_divisor(w, g)) / coefficient_functional([e], primitive_heegner_divisor(w, g))[0] for g in h]
    else:
        vertices = [coefficient_functional(L, [(1, g)]) / coefficient_functional([e], [(1, g)])[0] for g in h]
    return incircle_radius(vertices)

def _bound_constant(k):
    r"""
    The constant \tilde C in Lemma 3.1
    """
    _pi = math.pi
    gamma_k = math.gamma(k)
    ck = 2.125 + (2*_pi)**k / (gamma_k * (k - 2))
    ck2 = (4 * _pi)**((k - 1) / 2) * math.sqrt(ck) / math.sqrt(gamma_k / (k - 1))
    return ck2

def _bound(w, k, e, L, M, primitive = False):
    parity = (k in ZZ)
    _pi = math.pi
    discr = w.discriminant()
    D = (-1)**k * discr
    # eisenstein_bound is the constant denoted by C_{k, \Lambda}
    if parity:
        eisenstein_bound = 2 * (_pi / 2)**k / (math.sqrt(discr) * quadratic_L_function__exact(k, D) * factorial(k))
        for p in discr.prime_divisors():
            if p > 2:
                eisenstein_bound *= (1 - 1 / p)
    else:
        eisenstein_bound = 8 * (_pi / 2)**k / (5 * scipy.special.zeta(k - 1/2) * math.gamma(k) * math.sqrt(discr) * (1 - 2**(-1 - 2*k)))
        for p in discr.prime_divisors():
            if p > 2:
                eisenstein_bound *= ( (1 - 1 / p) / (1 - p**(-1 - 2 * k)))
    c = _bound_constant(k)
    if primitive:
        eisenstein_bound *= 0.215
        c *= (1 + w.discriminant() * (scipy.special.zeta(k) - 1))
    R = _radius_constant(w, k, e, L, M, primitive = primitive)
    B = math.gamma(k-1) * scipy.special.zeta(k - 2) * c * c * math.sqrt(len(M)) / ((4 * _pi)**(k - 1) * max(M).n()**(k / 2 - 1))
    bound = (R * eisenstein_bound / B) ** (2 / (2 - k))
    return bound


class HeegnerDivisor(object):
    r"""
    This class represents Heegner divisors.
    """
    def __init__(self, w, d, k):
        self.__dict = defaultdict(int, d)
        self.__w = w
        self.__k = k

    def __repr__(self):
        def a(n):
            if n == 1:
                return ''
            return str(n)+'*'
        return ' + '.join('%sH%s'%(a(y), x) for x, y in self.__dict.items() if y)

    def dict(self):
        return self.__dict

    def __getitem__(self, x):
        return self.__dict[x]

    def P(self):
        d = defaultdict(int, {})
        for x, y in self.__dict.items():
            x = primitive_heegner_divisor(self.__w, x, _flag = 1)
            for x in x:
                d[x[1]] += y
        return PrimitiveHeegnerDivisor(self.__w, d, self.__k)

    def __add__(self, other):
        if isinstance(other, PrimitiveHeegnerDivisor):
            return self.__add__(other.H())
        dict1 = self.dict()
        dict2 = other.dict()
        return HeegnerDivisor(self.__w, {x: dict1[x] + dict2[x] for x in set(dict1.keys()).union(set(dict2.keys()))}, self.__k)
    __radd__ = __add__

    def __sub__(self, other):
        if isinstance(other, PrimitiveHeegnerDivisor):
            return self.__sub__(other.H())
        dict1 = self.dict()
        dict2 = other.dict()
        return HeegnerDivisor(self.__w, {x: dict1[x] - dict2[x] for x in set(dict1.keys()).union(set(dict2.keys()))}, self.__k)

    def __mul__(self, n):
        d = self.dict()
        return HeegnerDivisor(self.__w, {x : n * y for x, y in d.items()}, self.__k)
    __rmul__ = __mul__

    def __neg__(self):
        return self.__mul__(-1)

    def functional(self, X = None):
        if X is None:
            w = self.__w
            k = self.__k
            w_dual = w.dual()
            bd = max(x[-1] for x in self.dict().keys())
            X = [w_dual.eisenstein_series(k, bd + 1)] + w_dual.cusp_forms_basis(k, bd + 1)
        return sum(c * vector(coefficient_functional(X, [(1, g)])) for g, c in self.dict().items())



class PrimitiveHeegnerDivisor(object):
    def __init__(self, w, d, k):
        self.__dict = defaultdict(int, d)
        self.__w = w
        self.__k = k

    def __repr__(self):
        def a(n):
            if n == 1:
                return ''
            return str(n)+'*'
        return ' + '.join('%sP%s'%(a(y), x) for x, y in self.__dict.items() if y)

    def dict(self):
        return self.__dict

    def __getitem__(self, x):
        return self.__dict[x]

    def H(self):
        d = defaultdict(int, {})
        for x, y in self.__dict.items():
            x = primitive_heegner_divisor(self.__w, x)
            for x in x:
                d[x[1]] += x[0] * y
        return HeegnerDivisor(self.__w, d, self.__k)

    def __add__(self, other):
        if isinstance(other, HeegnerDivisor):
            return self.__add__(other.P())
        dict1 = self.dict()
        dict2 = other.dict()
        return PrimitiveHeegnerDivisor(self.__w, {x: dict1[x] + dict2[x] for x in set(dict1.keys()).union(set(dict2.keys()))}, self.__k)
    __radd__ = __add__

    def __sub__(self, other):
        if isinstance(other, HeegnerDivisor):
            return self.__add__(other.P())
        dict1 = self.dict()
        dict2 = other.dict()
        return PrimitiveHeegnerDivisor(self.__w, {x: dict1[x] + dict2[x] for x in set(dict1.keys()).union(set(dict2.keys()))}, self.__k)

    def __mul__(self, n):
        d = self.dict()
        return PrimitiveHeegnerDivisor(self.__w, {x : n * y for x, y in d.items()}, self.__k)
    __rmul__ = __mul__

    def __neg__(self):
        return self.__mul__(-1)

    def functional(self, X = None):
        return self.H().functional(X = X)

class ConeOfHeegnerDivisors:

    def __init__(self, w, k, bound, vectors, letter, X = None):
        self.__vectors = vectors
        self.__w = w
        self.__k = k
        self.__bound = bound
        self.__letter = letter
        self.__X = X

    def __repr__(self):
        try:
            return self.__str
        except AttributeError:
            cone = self._cone()
            try:
                self.__str = self._identify_divisors(cone)
                return self.__str
            except ValueError:
                pass
            rays = [vector(x) for x in cone.ExtremeRays()]
            M, L = self._change_of_basis_matrix()
            divisors = [self.__letter+str(x) for x in L]
            rays_inv = [M.transpose().inverse() * ray for ray in rays]
            s = 'Cone of Heegner divisors defined by the following rays:\n'
            rays_inv2 = []
            heegner = []
            for ray in rays_inv:
                ray = ray * ray.denominator()
                ray /= gcd(ray)
                rays_inv2.append(ray)
                s += ' + '.join('%s*%s'%(x, divisors[i]) for i, x in enumerate(ray)) + '\n'
                if self.__letter == 'H':
                    heegner.append(HeegnerDivisor(self.__w, {divisors[i]:x for i, x in enumerate(ray)}, self.__k))
                else:
                    heegner.append(PrimitiveHeegnerDivisor(self.__w, {divisors[i]:x for i, x in enumerate(ray)}, self.__k))
            self.__str = s
            self.__rays = rays_inv2
            self.__heegner = heegner
            return s

    def check(self, bound):
        r"""
        Check that this cone contains all Heegner divisors up to 'bound'.
        """
        h = heegner_divisor_iterator(self.__w, bound)
        if self.__letter == 'H':
            a = self.H
        else:
            a = self.P
        for divisor in h:
            divisor = a(divisor)
            contains = self._contains(divisor)
            if not contains:
                raise RuntimeError('This cone does not contain %s. Try using a higher initial bound.'%divisor)

    def H(self, x):
        return HeegnerDivisor(self.__w, {x:1}, self.__k)

    def P(self, x):
        return PrimitiveHeegnerDivisor(self.__w, {x:1}, self.__k)

    def _change_of_basis_matrix(self):
        h = heegner_divisor_iterator(self.__w, self.__bound)
        M = []
        i = -1
        vectors = self.__vectors
        L = []
        for g in h:
            i += 1
            v = vectors[i]
            M1 = [x for x in M]
            M1 = M1 + [v]
            rank = matrix(M1).rank()
            if rank == len(v):
                L.append(g)
                return matrix(M1), L
            if rank > matrix(M).rank():
                M = M1
                L.append(g)

    def _cone(self):
        try:
            return self.__cone
        except AttributeError:
            self.__cone = NCone(cone = self.__vectors)
            return self.__cone

    def _identify_divisors(self, cone):
        rays = [vector(list(x)) for x in cone.ExtremeRays()]
        rays = [x / gcd(x) for x in rays]
        self.__rays = rays
        vectors = [vector(x) for x in self.__vectors]
        vectors = [x * denominator(x) for x in vectors]
        vectors = [x / gcd(x) for x in vectors]
        s = 'Cone of Heegner divisors defined by the following rays:\n'
        h = list(heegner_divisor_iterator(self.__w, self.__bound))
        heegner = []
        for ray in rays:
            try:
                i = vectors.index(ray)
                s += self.__letter + str(h[i]) + '\n'
                if self.__letter == 'H':
                    heegner.append(HeegnerDivisor(self.__w, {h[i]:1}, self.__k))
                else:
                    heegner.append(PrimitiveHeegnerDivisor(self.__w, {h[i]:1}, self.__k))
            except IndexError:
                raise ValueError from None
        self.__heegner = heegner
        return s

    def _convert_heegner_to_ray(self, h):
        if self.__letter == 'H' and isinstance(h, PrimitiveHeegnerDivisor):
            return self._convert_heegner_to_ray(h.H())
        elif self.__letter == 'P' and isinstance(h, HeegnerDivisor):
            return self._convert_heegner_to_ray(h.P())
        f = h.functional(X = self.__X)
        if not f:
            raise ValueError('This is not a Heegner divisor.')
        return f

    def contains(self, x):
        s = str(x)
        x = self._convert_heegner_to_ray(x)
        c = self._cone()
        h = c.SupportHyperplanes()
        p1 = all(vector(a) * vector(x) > 0 for a in h)
        if p1:
            return '%s is contained in the interior.'%s
        p2 = all(vector(a) * vector(x) >= 0 for a in h)
        if p2:
            return '%s lies on the boundary.'%s
        return '%s is not contained in the cone.'%s

    def _contains(self, x):
        s = str(x)
        x = self._convert_heegner_to_ray(x)
        c = self._cone()
        h = c.SupportHyperplanes()
        p1 = all(vector(a) * vector(x) > 0 for a in h)
        if p1:
            return 2
        p2 = all(vector(a) * vector(x) >= 0 for a in h)
        if p2:
            return 1
        return 0

    def rays(self):
        _ = self.__repr__()
        return self.__heegner