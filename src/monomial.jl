struct FullBasis{B<:AbstractMonomialIndexed,M<:MP.AbstractMonomial} <:
       SA.ImplicitBasis{Polynomial{B,M},M} end

function Base.getindex(::FullBasis{B,M}, mono::M) where {B,M}
    return Polynomial{B}(mono)
end

function Base.getindex(::FullBasis{B,M}, p::Polynomial{B,M}) where {B,M}
    return p.monomial
end

SA.mstructure(::FullBasis{B}) where {B} = Mul{B}()

MP.monomial_type(::Type{<:FullBasis{B,M}}) where {B,M} = M
function MP.polynomial_type(basis::FullBasis{B,M}, ::Type{T}) where {B,M,T}
    return MP.polynomial_type(typeof(basis), T)
end

# TODO Move it to SA as :
# struct SubBasis{T,I,B<:SA.ImplicitBasis{T,I},V<:AbstractVector{I}} <: SA.ExplicitBasis{T,Int}
#     implicit::B
#     indices::V
# end
struct SubBasis{B<:AbstractMonomialIndexed,M,V<:AbstractVector{M}} <:
       SA.ExplicitBasis{Polynomial{B,M},Int}
    monomials::V
end

# Overload some of the `AbstractVector` interface for convenience
Base.isempty(basis::SubBasis) = isempty(basis.monomials)
Base.eachindex(basis::SubBasis) = eachindex(basis.monomials)
_iterate(::SubBasis, ::Nothing) = nothing
function _iterate(basis::SubBasis{B}, elem_state) where {B}
    return parent(basis)[elem_state[1]], elem_state[2]
end
Base.iterate(basis::SubBasis) = _iterate(basis, iterate(basis.monomials))
Base.iterate(basis::SubBasis, s) = _iterate(basis, iterate(basis.monomials, s))
Base.length(basis::SubBasis) = length(basis.monomials)
Base.firstindex(basis::SubBasis) = firstindex(basis.monomials)
Base.lastindex(basis::SubBasis) = lastindex(basis.monomials)

MP.nvariables(basis::SubBasis) = MP.nvariables(basis.monomials)
MP.variables(basis::SubBasis) = MP.variables(basis.monomials)

Base.parent(::SubBasis{B,M}) where {B,M} = FullBasis{B,M}()

function Base.getindex(basis::SubBasis, index::Int)
    return parent(basis)[basis.monomials[index]]
end

function monomial_index(basis::SubBasis, mono::MP.AbstractMonomial)
    i = searchsortedfirst(basis.monomials, mono)
    if i in eachindex(basis.monomials) && basis.monomials[i] == mono
        return i
    end
    return
end

function Base.getindex(basis::SubBasis{B,M}, value::Polynomial{B,M}) where {B,M}
    mono = monomial_index(basis, parent(basis)[value])
    if isnothing(mono)
        throw(BoundsError(basis, value))
    end
    return mono
end

const MonomialIndexedBasis{B,M} = Union{SubBasis{B,M},FullBasis{B,M}}

MP.monomial_type(::Type{<:SubBasis{B,M}}) where {B,M} = M

# The `i`th index of output is the index of occurence of `x[i]` in `y`,
# or `0` if it does not occur.
function multi_findsorted(x, y)
    I = zeros(Int, length(x))
    j = 1
    for i in eachindex(x)
        while j ≤ length(y) && x[i] > y[j]
            j += 1
        end
        if j ≤ length(y) && x[i] == y[j]
            I[i] = j
        end
    end
    return I
end

function merge_bases(basis1::MB, basis2::MB) where {MB<:SubBasis}
    monos = MP.merge_monomial_vectors([basis1.monomials, basis2.monomials])
    I1 = multi_findsorted(monos, basis1.monomials)
    I2 = multi_findsorted(monos, basis2.monomials)
    return MB(monos), I1, I2
end

# Unsafe because we don't check that `monomials` is sorted and without duplicates
function unsafe_basis(
    ::Type{B},
    monomials::AbstractVector{M},
) where {B<:AbstractMonomialIndexed,M<:MP.AbstractMonomial}
    return SubBasis{B,M,typeof(monomials)}(monomials)
end

function Base.getindex(::FullBasis{B,M}, monomials::AbstractVector) where {B,M}
    return unsafe_basis(B, MP.monomial_vector(monomials)::AbstractVector{M})
end

function SubBasis{B}(
    monomials::AbstractVector,
) where {B<:AbstractMonomialIndexed}
    return unsafe_basis(
        B,
        MP.monomial_vector(monomials)::AbstractVector{<:MP.AbstractMonomial},
    )
end

function Base.copy(basis::SubBasis)
    return typeof(basis)(copy(basis.monomials))
end

Base.:(==)(a::SubBasis, b::SubBasis) = a.monomials == b.monomials

function algebra_type(::Type{BT}) where {B,M,BT<:MonomialIndexedBasis{B,M}}
    return Algebra{BT,B,M}
end

implicit_basis(::SubBasis{B,M}) where {B,M} = FullBasis{B,M}()
implicit_basis(basis::FullBasis) = basis

function MA.promote_operation(::typeof(implicit_basis), ::Type{<:Union{FullBasis{B,M},SubBasis{B,M}}}) where {B,M}
    return FullBasis{B,M}
end

function _explicit_basis(coeffs, ::FullBasis{B}) where {B}
    return SubBasis{B}(SA.keys(coeffs))
end

_explicit_basis(_, basis::SubBasis) = basis

explicit_basis(a::SA.AlgebraElement) = _explicit_basis(SA.coeffs(a), SA.basis(a))

function explicit_basis_type(::Type{FullBasis{B,M}}) where {B,M}
    return SubBasis{B,M,MP.monomial_vector_type(M)}
end

function empty_basis(
    ::Type{<:SubBasis{B,M}},
) where {B<:AbstractMonomialIndexed,M}
    return unsafe_basis(B, MP.empty_monomial_vector(M))
end

function maxdegree_basis(
    ::FullBasis{B},
    variables,
    maxdegree::Int,
) where {B<:AbstractMonomialIndexed}
    return unsafe_basis(B, MP.monomials(variables, 0:maxdegree))
end

MP.variables(c::SA.AbstractCoefficients) = MP.variables(SA.keys(c))

function sparse_coefficients(p::MP.AbstractPolynomial)
    return SA.SparseCoefficients(MP.monomials(p), MP.coefficients(p))
end

function sparse_coefficients(t::MP.AbstractTerm)
    return SA.SparseCoefficients((MP.monomial(t),), (MP.coefficient(t),))
end

function MA.promote_operation(
    ::typeof(sparse_coefficients),
    ::Type{P},
) where {P<:MP.AbstractPolynomialLike}
    M = MP.monomial_type(P)
    T = MP.coefficient_type(P)
    return SA.SparseCoefficients{
        M,
        T,
        MP.monomial_vector_type(M),
        Vector{T},
    }
end

function algebra_element(p::Polynomial{B,M}) where {B,M}
    return algebra_element(sparse_coefficients(MP.term(1, p.monomial)), FullBasis{B,M}())
end

function algebra_element(f::Function, basis::SubBasis)
    return algebra_element(map(f, eachindex(basis)), basis)
end

function constant_algebra_element(::Type{FullBasis{B,M}}, ::Type{T}) where {B,M,T}
    return algebra_element(sparse_coefficients(MP.polynomial(MP.term(one(T), MP.constant_monomial(M)))), FullBasis{B,M}())
end

function constant_algebra_element(::Type{<:SubBasis{B,M}}, ::Type{T}) where {B,M,T}
    return algebra_element([one(T)], SubBasis{B}([MP.constant_monomial(M)]))
end

function _show(io::IO, mime::MIME, basis::SubBasis{B}) where {B}
    print(io, "SubBasis{$(nameof(B))}")
    print(io, "([")
    first = true
    # TODO use Base.show_vector here, maybe by wrapping the `generator` vector
    #      into something that spits objects wrapped with the `mime` type
    for mono in basis.monomials
        if !first
            print(io, ", ")
        end
        first = false
        show(io, mime, mono)
    end
    return print(io, "])")
end

function Base.show(io::IO, mime::MIME"text/plain", basis::SubBasis)
    return _show(io, mime, basis)
end

function Base.show(io::IO, mime::MIME"text/print", basis::SubBasis)
    return _show(io, mime, basis)
end

function Base.print(io::IO, basis::SubBasis)
    return show(io, MIME"text/print"(), basis)
end

function Base.show(io::IO, basis::SubBasis)
    return show(io, MIME"text/plain"(), basis)
end

abstract type AbstractMonomial <: AbstractMonomialIndexed end

function basis_covering_monomials(
    ::FullBasis{B},
    monos::AbstractVector,
) where {B<:AbstractMonomial}
    return SubBasis{B}(monos)
end

Base.adjoint(p::Polynomial{B}) where {B<:AbstractMonomialIndexed} = Polynomial{B}(adjoint(p.monomial))

"""
    struct Monomial <: AbstractMonomialIndexed end

Monomial basis with the monomials of the vector `monomials`.
For instance, `SubBasis{Monomial}([1, x, y, x^2, x*y, y^2])` is the monomial basis
for the subspace of quadratic polynomials in the variables `x`, `y`.

This basis is orthogonal under a scalar product defined with the complex Gaussian measure as density.
Once normalized so as to be orthonormal with this scalar product,
one get ths [`ScaledMonomial`](@ref).
"""
struct Monomial <: AbstractMonomial end

(::Mul{Monomial})(a::MP.AbstractMonomial, b::MP.AbstractMonomial) = a * b

SA.coeffs(p::Polynomial{Monomial}, ::FullBasis{Monomial}) = p.monomial

function MP.polynomial_type(
    ::Union{SubBasis{B,M},Type{<:SubBasis{B,M}}},
    ::Type{T},
) where {B,M,T}
    return MP.polynomial_type(FullBasis{B,M}, T)
end

function MP.polynomial_type(::Type{FullBasis{B,M}}, ::Type{T}) where {B,M,T}
    return MP.polynomial_type(Polynomial{B,M}, T)
end

function MP.polynomial_type(
    ::Type{Polynomial{Monomial,M}},
    ::Type{T},
) where {M,T}
    return MP.polynomial_type(M, T)
end

function MP.polynomial(f::Function, mb::SubBasis{Monomial})
    return MP.polynomial(f, mb.monomials)
end

function MP.polynomial(Q::AbstractMatrix, mb::SubBasis{Monomial}, T::Type)
    return MP.polynomial(Q, mb.monomials, T)
end

function MP.coefficients(
    p::MP.AbstractPolynomialLike,
    basis::SubBasis{Monomial},
)
    return MP.coefficients(p, basis.monomials)
end

function MP.coefficients(p::MP.AbstractPolynomialLike, ::FullBasis{Monomial})
    return p
end

function _assert_constant(α) end

function _assert_constant(x::Union{Polynomial,SA.AlgebraElement,MP.AbstractPolynomialLike})
    error("Expected constant element, got type `$(typeof(x))`")
end

#function MA.operate!(::SA.UnsafeAddMul{<:Mul{Monomial}}, p::MP.AbstractPolynomial, args::Vararg{Any,N}) where {N}
#    return MA.operate!(MA.add_mul, p, args...)
#end

#function MA.operate!(
#    ::SA.UnsafeAddMul{Mul{B}},
#    res::SA.AbstractCoefficients,
#    v::SA.AbstractCoefficients,
#    w::SA.AbstractCoefficients,
#) where {B<:MB.AbstractMonomial}
#    for (kv, a) in nonzero_pairs(v)
#        for (kw, b) in nonzero_pairs(w)
#            SA.unsafe_push!(res, kv * kw, a * b)
#            c = ms.structure(kv, kw)
#            for (k, v) in nonzero_pairs(c)
#            end
#        end
#    end
#    return res
#end

#function MA.operate!(op::SA.UnsafeAddMul{Mul{B}}, a::SA.AbstractCoefficients, α, b::SA.AbstractCoefficients) where {B<:MB.AbstractMonomial}
#    for
#    MA.operate!(op, a, α, Polynomial{Monomial}(x.monomial * y.monomial * z.monomial))
#    return a
#end

function MA.operate!(::SA.UnsafeAddMul{typeof(*)}, a::SA.AlgebraElement{<:Algebra{<:MonomialIndexedBasis,Monomial}}, α, x::Polynomial{Monomial})
    _assert_constant(α)
    SA.unsafe_push!(a, x, α)
    return a
end

# Overload some of the `MP` interface for convenience
MP.mindegree(basis::SubBasis{Monomial}) = MP.mindegree(basis.monomials)
MP.maxdegree(basis::SubBasis) = MP.maxdegree(basis.monomials)
MP.extdegree(basis::SubBasis{Monomial}) = MP.extdegree(basis.monomials)
function MP.mindegree(basis::SubBasis{Monomial}, v)
    return MP.mindegree(basis.monomials, v)
end
function MP.maxdegree(basis::SubBasis, v)
    return MP.maxdegree(basis.monomials, v)
end
function MP.extdegree(basis::SubBasis{Monomial}, v)
    return MP.extdegree(basis.monomials, v)
end
