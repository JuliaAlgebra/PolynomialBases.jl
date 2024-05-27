# TODO Add to MultivariatePolynomials
Base.keytype(p::MP.AbstractPolynomialLike) = MP.monomial_type(p)
Base.valtype(p::MP.AbstractPolynomialLike) = MP.coefficient_type(p)
#Base.keys(p::MP.AbstractPolynomial) = MP.monomials(p)
SA.nonzero_pairs(p::MP.AbstractPolynomialLike) = MP.terms(p)
function Base.similar(p::PT, ::Type{T}) where {PT<:MP.AbstractPolynomial,T}
    return convert(MP.similar_type(PT, T), copy(p)) # Missing the `copy` in MP
end
Base.iterate(t::MP.Term) = iterate(t, 1)
function Base.iterate(t::MP.Term, state)
    if state == 1
        return MP.monomial(t), 2
    elseif state == 2
        return MP.coefficient(t), 3
    else
        return nothing
    end
end
function MA.operate!(
    ::SA.UnsafeAddMul{typeof(*)},
    mc::MP.AbstractPolynomial,
    val,
    c::MP.AbstractPolynomial,
)
    return MA.operate!(MA.add_mul, mc, val, c)
end
MA.operate!(::typeof(SA.canonical), p::MP.AbstractPolynomial) = p
function MA.promote_operation(
    ::typeof(SA.canonical),
    ::Type{P},
) where {P<:MP.AbstractPolynomialLike}
    return P
end

abstract type AbstractMonomialIndexed end

struct Polynomial{B<:AbstractMonomialIndexed,M<:MP.AbstractMonomial}
    monomial::M
    function Polynomial{B}(mono::MP.AbstractMonomial) where {B}
        return new{B,typeof(mono)}(mono)
    end
end

function Polynomial{B}(v::MP.AbstractVariable) where {B}
    return Polynomial{B}(MP.monomial(v))
end

function Base.:(==)(p::Polynomial{B}, q::Polynomial{B}) where {B}
    return p.monomial == q.monomial
end

MP.variables(p::Polynomial) = MP.variables(p.monomial)
MP.nvariables(p::Polynomial) = MP.nvariables(p.monomial)

function _algebra_element(p, ::Type{B}) where {B}
    return SA.AlgebraElement(p, _algebra(FullBasis{B,MP.monomial_type(p)}()))
end

function _algebra_element(p::Polynomial{B,M}) where {B,M}
    return _algebra_element(p.monomial, B)
end

function Base.:*(a::Polynomial{B}, b::Polynomial{B}) where {B}
    return _algebra_element(Mul{B}()(a.monomial, b.monomial), B)
end

function Base.:*(a::Polynomial{B}, b::SA.AlgebraElement) where {B}
    aa =_algebra_element(a)
    @show parent(aa).basis
    @show parent(b).basis
    @show parent(aa).basis == parent(b).basis
    @show parent(aa) == parent(b)
    return aa * b
end

function _show(io::IO, mime::MIME, p::Polynomial{B}) where {B}
    print(io, B)
    print(io, "(")
    show(io, mime, p.monomial)
    return print(io, ")")
end
function Base.show(io::IO, mime::MIME"text/plain", p::Polynomial)
    return _show(io, mime, p)
end
function Base.show(io::IO, p::Polynomial)
    return show(io, MIME"text/plain"(), p)
end

function Base.zero(::Type{Polynomial{B,M}}) where {B,M}
    return _algebra_element(zero(MP.polynomial_type(M, Rational{Int})), B)
end

Base.zero(p::Polynomial) = zero(typeof(p))

function convert_basis(basis::SA.AbstractBasis, p::MP.AbstractPolynomialLike)
    return convert_basis(basis, _algebra_element(p, Monomial))
end

function convert_basis(basis::SA.AbstractBasis, p::SA.AlgebraElement)
    return SA.AlgebraElement(SA.coeffs(p, basis), _algebra(basis))
end

struct Mul{B<:AbstractMonomialIndexed} <: SA.MultiplicativeStructure end
