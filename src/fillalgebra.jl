const FillVector{F,A} = Fill{F,1,A}
const FillMatrix{F,A} = Fill{F,2,A}
const OnesVector{F,A} = Ones{F,1,A}
const OnesMatrix{F,A} = Ones{F,2,A}
const ZerosVector{F,A} = Zeros{F,1,A}
const ZerosMatrix{F,A} = Zeros{F,2,A}

## vec

vec(a::Ones{T}) where T = Ones{T}(length(a))
vec(a::Zeros{T}) where T = Zeros{T}(length(a))
vec(a::Fill{T}) where T = Fill{T}(a.value,length(a))

## Transpose/Adjoint
# cannot do this for vectors since that would destroy scalar dot product


transpose(a::Ones{T,2}) where T = Ones{T}(reverse(a.axes))
adjoint(a::Ones{T,2}) where T = Ones{T}(reverse(a.axes))
transpose(a::Zeros{T,2}) where T = Zeros{T}(reverse(a.axes))
adjoint(a::Zeros{T,2}) where T = Zeros{T}(reverse(a.axes))
transpose(a::Fill{T,2}) where T = Fill{T}(transpose(a.value), reverse(a.axes))
adjoint(a::Fill{T,2}) where T = Fill{T}(adjoint(a.value), reverse(a.axes))

permutedims(a::AbstractFill{<:Any,1}) = fillsimilar(a, (1, length(a)))
permutedims(a::AbstractFill{<:Any,2}) = fillsimilar(a, reverse(a.axes))

function permutedims(B::AbstractFill, perm)
    dimsB = size(B)
    ndimsB = length(dimsB)
    (ndimsB == length(perm) && isperm(perm)) || throw(ArgumentError("no valid permutation of dimensions"))
    dimsP = ntuple(i->dimsB[perm[i]], ndimsB)::typeof(dimsB)
    fillsimilar(B, dimsP)
end

## Algebraic identities


function mult_fill(a::AbstractFill, b::AbstractFill{<:Any,2})
    axes(a, 2) ≠ axes(b, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    return Fill(getindex_value(a)*getindex_value(b)*size(a,2), (axes(a, 1), axes(b, 2)))
end

function mult_fill(a::AbstractFill, b::AbstractFill{<:Any,1})
    axes(a, 2) ≠ axes(b, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    return Fill(getindex_value(a)*getindex_value(b)*size(a,2), (axes(a, 1),))
end

function mult_ones(a::AbstractVector, b::AbstractMatrix)
    axes(a, 2) ≠ axes(b, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    return Ones{promote_type(eltype(a), eltype(b))}((axes(a, 1), axes(b, 2)))
end

function mult_zeros(a, b::AbstractMatrix)
    axes(a, 2) ≠ axes(b, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    return Zeros{promote_type(eltype(a), eltype(b))}((axes(a, 1), axes(b, 2)))
end
function mult_zeros(a, b::AbstractVector)
    axes(a, 2) ≠ axes(b, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    return Zeros{promote_type(eltype(a), eltype(b))}((axes(a, 1),))
end

*(a::AbstractFill{<:Any,1}, b::AbstractFill{<:Any,2}) = mult_fill(a,b)
*(a::AbstractFill{<:Any,2}, b::AbstractFill{<:Any,2}) = mult_fill(a,b)
*(a::AbstractFill{<:Any,2}, b::AbstractFill{<:Any,1}) = mult_fill(a,b)

*(a::Ones{<:Any,1}, b::Ones{<:Any,2}) = mult_ones(a, b)

*(a::Zeros{<:Any,1}, b::Zeros{<:Any,2}) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::Zeros{<:Any,2}) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::Zeros{<:Any,1}) = mult_zeros(a, b)

*(a::Zeros{<:Any,1}, b::AbstractFill{<:Any,2}) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::AbstractFill{<:Any,2}) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::AbstractFill{<:Any,1}) = mult_zeros(a, b)
*(a::AbstractFill{<:Any,1}, b::Zeros{<:Any,2}) = mult_zeros(a,b)
*(a::AbstractFill{<:Any,2}, b::Zeros{<:Any,2}) = mult_zeros(a,b)
*(a::AbstractFill{<:Any,2}, b::Zeros{<:Any,1}) = mult_zeros(a,b)

*(a::Zeros{<:Any,1}, b::AbstractMatrix) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::AbstractMatrix) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::AbstractTriangular) = mult_zeros(a, b)
*(a::AbstractMatrix, b::Zeros{<:Any,1}) = mult_zeros(a, b)
*(a::AbstractMatrix, b::Zeros{<:Any,2}) = mult_zeros(a, b)
*(a::AbstractTriangular, b::Zeros{<:Any,2}) = mult_zeros(a, b)
*(a::Zeros{<:Any,1}, b::AbstractVector) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::AbstractVector) = mult_zeros(a, b)
*(a::AbstractVector, b::Zeros{<:Any,2}) = mult_zeros(a, b)

*(a::Zeros{<:Any,1}, b::Diagonal) = mult_zeros(a, b)
*(a::Zeros{<:Any,2}, b::Diagonal) = mult_zeros(a, b)
*(a::Diagonal, b::Zeros{<:Any,1}) = mult_zeros(a, b)
*(a::Diagonal, b::Zeros{<:Any,2}) = mult_zeros(a, b)

function *(a::Diagonal, b::AbstractFill{T,2}) where T 
    size(a,2) == size(b,1) || throw(DimensionMismatch("A has dimensions $(size(a)) but B has dimensions $(size(b))"))
    a.diag .* b # use special broadcast
end
function *(a::AbstractFill{T,2}, b::Diagonal) where T
    size(a,2) == size(b,1) || throw(DimensionMismatch("A has dimensions $(size(a)) but B has dimensions $(size(b))"))
    a .* permutedims(b.diag) # use special broadcast
end

function mult_sum2(x::AbstractMatrix, f::AbstractFill{T,2}) where T
    axes(x, 2) ≠ axes(f, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    m = size(f, 2)
    repeat(sum(x, dims=2) * getindex_value(f), 1, m) 
end

function mult_sum1(f::AbstractFill{T,2}, x::AbstractMatrix) where T
    axes(f, 2) ≠ axes(x, 1) &&
        throw(DimensionMismatch("Incompatible matrix multiplication dimensions"))
    m = size(f, 1)
    repeat(sum(x, dims=1) * getindex_value(f), m, 1) 
end

*(x::AbstractMatrix, y::AbstractFill{<:Any,2}) = mult_sum2(x, y)
*(x::AbstractTriangular, y::AbstractFill{<:Any,2}) = mult_sum2(x, y)
*(x::AbstractFill{<:Any,2}, y::AbstractMatrix) = mult_sum1(x, y)
*(x::AbstractFill{<:Any,2}, y::AbstractTriangular) = mult_sum1(x, y)


### These methods are faster for small n #############
# function *(a::Adjoint{T, <:StridedMatrix{T}}, b::Fill{T, 2}) where T
#     fB = similar(parent(a), size(b, 1), size(b, 2))
#     fill!(fB, b.value)
#     return a*fB
# end

# function *(a::Transpose{T, <:StridedMatrix{T}}, b::Fill{T, 2}) where T
#     fB = similar(parent(a), size(b, 1), size(b, 2))
#     fill!(fB, b.value)
#     return a*fB
# end

# function *(a::StridedMatrix{T}, b::Fill{T, 2}) where T
#     fB = similar(a, size(b, 1), size(b, 2))
#     fill!(fB, b.value)
#     return a*fB
# end

## Matrix-Vector multiplication

*(a::Adjoint{T, <:StridedMatrix{T}},   b::AbstractFill{T, 1}) where T = 
    reshape(sum(conj.(parent(a)); dims=1) .* getindex_value(b), size(parent(a), 2))
*(a::Transpose{T, <:StridedMatrix{T}}, b::AbstractFill{T, 1}) where T = 
    reshape(sum(parent(a); dims=1) .* getindex_value(b), size(parent(a), 2))
*(a::StridedMatrix{T}, b::AbstractFill{T, 1}) where T = 
    reshape(sum(a; dims=2) .* getindex_value(b), size(a, 1))


function _adjvec_mul_zeros(a::Adjoint{T}, b::Zeros{S, 1}) where {T, S}
    la, lb = length(a), length(b)
    if la ≠ lb
        throw(DimensionMismatch("dot product arguments have lengths $la and $lb"))
    end
    return zero(Base.promote_op(*, T, S))
end

*(a::AdjointAbsVec, b::Zeros{<:Any, 1}) = _adjvec_mul_zeros(a, b)
*(a::AdjointAbsVec{<:Number}, b::Zeros{<:Number, 1}) = _adjvec_mul_zeros(a, b)
*(a::Adjoint{T, <:AbstractMatrix{T}} where T, b::Zeros{<:Any, 1}) = mult_zeros(a, b)

function *(a::Transpose{T, <:AbstractVector{T}}, b::Zeros{T, 1}) where T<:Real
    la, lb = length(a), length(b)
    if la ≠ lb
        throw(DimensionMismatch("dot product arguments have lengths $la and $lb"))
    end
    return zero(T)
end
*(a::Transpose{T, <:AbstractMatrix{T}}, b::Zeros{T, 1}) where T<:Real = mult_zeros(a, b)


+(a::Zeros) = a
-(a::Zeros) = a

# Zeros +/- Zeros
function +(a::Zeros{T}, b::Zeros{V}) where {T, V}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return Zeros{promote_type(T,V)}(size(a)...)
end
-(a::Zeros, b::Zeros) = -(a + b)
-(a::Ones, b::Ones) = Zeros(a)+Zeros(b)

# Zeros +/- Fill and Fill +/- Zeros
function +(a::AbstractFill{T}, b::Zeros{V}) where {T, V}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return convert(AbstractFill{promote_type(T, V)}, a)
end
+(a::Zeros, b::AbstractFill) = b + a
-(a::AbstractFill, b::Zeros) = a + b
-(a::Zeros, b::AbstractFill) = a + (-b)

# Zeros +/- Array and Array +/- Zeros
function +(a::Zeros{T, N}, b::AbstractArray{V, N}) where {T, V, N}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return AbstractArray{promote_type(T,V),N}(b)
end
function +(a::Array{T, N}, b::Zeros{V, N}) where {T, V, N}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return AbstractArray{promote_type(T,V),N}(a)
end

function -(a::Zeros{T, N}, b::AbstractArray{V, N}) where {T, V, N}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return -b + a
end
-(a::Array{T, N}, b::Zeros{V, N}) where {T, V, N} = a + b


+(a::AbstractRange, b::Zeros) = b + a

function +(a::Zeros{T, 1}, b::AbstractRange) where {T}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    Tout = promote_type(T, eltype(b))
    return convert(Tout, first(b)):convert(Tout, step(b)):convert(Tout, last(b))
end
function +(a::Zeros{T, 1}, b::UnitRange) where {T}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    Tout = promote_type(T, eltype(b))
    return convert(Tout, first(b)):convert(Tout, last(b))
end

function -(a::Zeros{T, 1}, b::AbstractRange{V}) where {T, V}
    size(a) ≠ size(b) && throw(DimensionMismatch("dimensions must match."))
    return -b + a
end
-(a::AbstractRange{T}, b::Zeros{V, 1}) where {T, V} = a + b



####
# norm
####

for op in (:norm1, :norm2, :normInf, :normMinusInf)
    @eval $op(a::Zeros) = norm(getindex_value(a))
end

normp(a::Zeros, p) = norm(getindex_value(a))

norm1(a::AbstractFill) = length(a)*norm(getindex_value(a))
norm2(a::AbstractFill) = sqrt(length(a))*norm(getindex_value(a))
normp(a::AbstractFill, p) = (length(a))^(1/p)*norm(getindex_value(a))
normInf(a::AbstractFill) = norm(getindex_value(a))
normMinusInf(a::AbstractFill) = norm(getindex_value(a))


###
# lmul!/rmul!
###

function lmul!(x::Number, z::AbstractFill)
    λ = getindex_value(z)
    # Following check ensures consistency w/ lmul!(x, Array(z))
    # for, e.g., lmul!(NaN, z)
    x*λ == λ || throw(ArgumentError("Cannot scale by $x"))
    z
end

function rmul!(z::AbstractFill, x::Number)
    λ = getindex_value(z)
    # Following check ensures consistency w/ lmul!(x, Array(z))
    # for, e.g., lmul!(NaN, z)
    λ*x == λ || throw(ArgumentError("Cannot scale by $x"))
    z
end

fillzero(::Type{Fill{T,N,AXIS}}, n, m) where {T,N,AXIS} = Fill{T,N,AXIS}(zero(T), (n, m))
fillzero(::Type{Zeros{T,N,AXIS}}, n, m) where {T,N,AXIS} = Zeros{T,N,AXIS}((n, m))
fillzero(::Type{F}, n, m) where F = throw(ArgumentError("Cannot create a zero array of type $F"))

diagzero(D::Diagonal{F}, i, j) where F<:AbstractFill = fillzero(F, axes(D.diag[i], 1), axes(D.diag[j], 2))
