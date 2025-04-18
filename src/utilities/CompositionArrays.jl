# Arrays of compositions, using StructArrays.jl
struct CompositionArray{T,N,C,I} <: AbstractArray{T,N}
    data::StructArray{T,N,C,I}
end
CompositionArray(args...) = CompositionArray(StructArray(args...))
CompositionArray{T}(args...) where {T<:AbstractComposition} = CompositionArray(StructArray{T}(args...))
export CompositionArray

# Forward properties from wrapped StructArray
@inline Base.propertynames(x::CompositionArray) = propertynames(getfield(x, :data))
@inline Base.hasproperty(x::CompositionArray, key::Symbol) = hasproperty(getfield(x, :data), key)
@inline Base.getproperty(x::CompositionArray, key::Symbol) = getproperty(getfield(x, :data), key)

# Forward array interface to wrapped StructArray
@inline Base.setindex!(x::CompositionArray, args...) = setindex!(getfield(x, :data), args...)
@inline Base.getindex(x::CompositionArray, args...) = CompositionArray(getindex(getfield(x, :data), args...))
@inline Base.getindex(x::CompositionArray, inds::Vararg{Int}) = getindex(getfield(x, :data), inds...)
@inline Base.size(x::CompositionArray, args...) = size(getfield(x, :data), args...)
@inline Base.axes(x::CompositionArray, args...) = axes(getfield(x, :data), args...)
@inline Base.view(x::CompositionArray, args...) = CompositionArray(view(getfield(x, :data), args...))
@inline Base.copy(x::CompositionArray) = CompositionArray(copy(getfield(x, :data)))

# Key-based indexing
@inline Base.keys(x::CompositionArray) = propertynames(x)
@inline Base.haskey(x::CompositionArray, key::Symbol) = hasproperty(x, key)
@inline Base.getindex(x::CompositionArray, key::Symbol) = getproperty(x, key)

# Major and trace elements: general fallback method
majorelements(x::CompositionArray) = filter(k->contains(String(k),"O"), keys(x))
traceelements(x::CompositionArray) = filter(k->!contains(String(k),"O"), keys(x))
# Major and trace elements: forward to Composition type if known
majorelements(x::CompositionArray{T}) where {T<:AbstractComposition} = majorelements(T)
traceelements(x::CompositionArray{T}) where {T<:AbstractComposition} = traceelements(T)

# Extend StatGeochemBase.renormalize! for CompositionArray{<:AbstractComposition}
function StatGeochemBase.renormalize!(x::CompositionArray{<:AbstractComposition}; anhydrous::Bool=false)
    for i in eachindex(x)
        xᵢ = x[i]
        c = anhydrous ? normconstanhydrous(xᵢ) : normconst(xᵢ)
        if !(c ≈ 1)
            x[i] = xᵢ/c
        end
    end
    return x
end

function partiallymix!(x::CompositionArray, mixingfraction::Number, ifirst=findfirst(!isnan, getfield(x,:data)), ilast=findlast(!isnan, getfield(x,:data)))
    @assert 0 <= mixingfraction <= 1 "Mixing fraction must be between 0 and 1"
    unmixingfraction = 1 - mixingfraction
    xfirst, xlast = x[ifirst], x[ilast]
    Δi = ilast-ifirst
    for i in ifirst:ilast
        fᵢ = (i - ifirst)/Δi
        mixᵢ = (fᵢ*xlast + (1-fᵢ)*xfirst)
        x[i] = unmixingfraction * x[i] + mixingfraction * mixᵢ
    end
    return x
end
export partiallymix!