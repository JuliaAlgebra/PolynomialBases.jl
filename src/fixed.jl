"""
    struct FixedBasis{B,M,T,V} <:
        SA.ExplicitBasis{SA.AlgebraElement{Algebra{FullBasis{B,M},B,M},T,V},Int}
        elements::Vector{SA.AlgebraElement{Algebra{FullBasis{B,M},B,M},T,V}}
    end

Fixed basis with polynomials `elements`.
"""
struct FixedBasis{B,M,T,V} <:
       SA.ExplicitBasis{SA.AlgebraElement{Algebra{FullBasis{B,M},B,M},T,V},Int}
    elements::Vector{SA.AlgebraElement{Algebra{FullBasis{B,M},B,M},T,V}}
end

Base.length(b::FixedBasis) = length(b.elements)
Base.getindex(b::FixedBasis, i::Integer) = b.elements[i]

function Base.show(io::IO, b::FixedBasis)
    print(io, "FixedBasis(")
    _show_vector(io, MIME"text/plain"(), b.elements)
    print(io, ")")
    return
end

"""
    struct SemisimpleBasis{T,I,B<:SA.ExplicitBasis{T,I}} <: SA.ExplicitBasis{T,I}
        bases::Vector{B}
    end

Semisimple basis for use with [SymbolicWedderburn](https://github.com/kalmarek/SymbolicWedderburn.jl/).
Its elements are of [`SemisimpleElement`](@ref)s.
"""
struct SemisimpleBasis{T,I,B<:SA.ExplicitBasis{T,I}} <: SA.ExplicitBasis{T,I}
    bases::Vector{B}
end

Base.length(b::SemisimpleBasis) = length(first(b.bases))

"""
    struct SemisimpleElement{P}
        polynomials::Vector{P}
    end

Elements of [`SemisimpleBasis`](@ref).
"""
struct SemisimpleElement{P}
    elements::Vector{P}
end
SA.star(p::SemisimpleElement) = SemisimpleElement(SA.star.(p.elements))

function Base.getindex(b::SemisimpleBasis, i::Integer)
    return SemisimpleElement(getindex.(b.bases, i))
end

function Base.show(io::IO, b::SemisimpleBasis)
    if length(b.bases) == 1
        print(io, "Simple basis:")
    else
        print(io, "Semisimple basis with $(length(b.bases)) simple sub-bases:")
    end
    for basis in b.bases
        println(io)
        print(io, "  ")
        print(io, basis)
    end
end
