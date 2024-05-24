"""
    abstract type AbstractPolynomialBasis end

Polynomial basis of a subspace of the polynomials [Section~3.1.5, BPT12].

[BPT12] Blekherman, G.; Parrilo, P. A. & Thomas, R. R.
*Semidefinite Optimization and Convex Algebraic Geometry*.
Society for Industrial and Applied Mathematics, **2012**.
"""
abstract type AbstractPolynomialBasis end

# TODO breaking Should be underscore and only for internal use
generators(basis::AbstractPolynomialBasis) = basis.polynomials

function Base.getindex(
    basis::AbstractPolynomialBasis,
    I::AbstractVector{<:Integer},
)
    return typeof(basis)(generators(basis)[I])
end

"""
    maxdegree_basis(basis::StarAlgebras.AbstractBasis, variables, maxdegree::Int)

Return the explicit version of `basis`generating all polynomials of degree up to
`maxdegree` with variables `variables`.
"""
function maxdegree_basis end

"""
    basis_covering_monomials(basis::StarAlgebras.AbstractBasis, monos::AbstractVector{<:AbstractMonomial})

Return the minimal basis of type `B` that can generate all polynomials of the
monomial basis generated by `monos`.

## Examples

For example, to generate all the polynomials with nonzero coefficients for the
monomials `x^4` and `x^2`, we need three polynomials as otherwise, we generate
polynomials with nonzero constant term.
```jldoctest
julia> using DynamicPolynomials

julia> @polyvar x
(x,)

julia> basis_covering_monomials(Chebyshev, [x^2, x^4])
SubBasis{ChebyshevFirstKind}([1, x², x⁴])
```
"""
function basis_covering_monomials end
