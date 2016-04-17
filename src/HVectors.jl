module HVectors 

import Base: length, 
             getindex,
             push!,
             show,
             eltype,
             size,
             lock, 
             unlock

export HVector, islocked, @unlocked, idxtype

"""
    The type `HVector` is a container type that mimics the behaviour of an 
    heterogeneous array of n-tuples of varying size, but with elements of 
    the same type, e.g. the vector

        x = [(5, 8), (3, 1, 2), (4, )]

    or the vector of

        type foo
            a::Float64
        end
        x = [(foo(5), foo(8)), (foo(3), foo(1), foo(2)), (foo(4), )]

    It uses an efficient internal storage structure that avoid excessively
    slow code generation due to the abstractness of the above containers. The 
    first above vector of integer n-tuples is stored efficiently using the 
    two arrays:

               + - + - + - + - + - + - +
        data = | 5 | 8 | 3 | 1 | 2 | 4 |
               + - + - + - + - + - + - +
              
               + - + - + - + - +
        idxs = | 0 | 2 | 5 | 6 |
               + - + - + - + - + 

    This type supports a limited subset of the operations that are allowed 
    on a standard `Vector` type object. These are

    ~ pushing a new vector or a tuple

        xs = HVector{Int64}()
        push!(xs, [1, 2])
        push!(xs, (4, 5, 6))

    ~ read-only indexing 

        xs = HVector{Int64}()
        push!(xs, [1, 2])
        @assert xs[1] == [1, 2]

    Other operations, e.g. insertion, changing values of an entry, are not 
    yet implemented. 

    The indexing operation in the code

        xs = HVector{Int64}()
        push!(xs, [1, 2])
        x = xs[1]

    returns an object `x` of the type `HElement`. This object is, effectively, 
    a view on the underlying data storage, and can be indexed and used as if 
    it was a tuple, e.g. 

        println(x)
        [1, 2]

    Although nothing prevents you for digging into the underlying storage of 
    `x` and change its contents, `HElement`s object should be regarded as 
    immutables, as tuples are.

    Sometimes, when data comes from a streaming source the elements of a new 
    tuple to be appended arrive one at a time. In these cases one can use the 
    following code (made as an example)

        xs = HVector{Int64}()

        unlock(xs)
        for i = 1:3
            push!(xs, i)
        end
        lock(xs)

    First the storage is unlocked using `unlock(xs)`, to allow appending 
    incrementally samples from the stream. Pushing a new value on a locked
    `HVector` results in an error. Samples are then obtained from the stream
    and appended to the underlying data storage. When the job is finished the 
    `HVector` is locked again, and will contain a new entry, i.e.

        println(xs[i])
        [1, 2, 3]

    One can also use the syntax 

        @unlocked xs for i = 1:3
            push!(xs, i)
        end

    to achieve the same thing and achieve the same effect.

"""
type HVector{T<:Number, S<:Integer} <: AbstractVector{T}
    data::Vector{T}
    idxs::Vector{S}
    locked::Bool
    pushed::Int
    HVector() = new(T[], S[0], true, 0)
    function HVector(data::Vector{T}, idxs::Vector{S}, chksorted::Bool=true) 
        chksorted && (issorted(idxs) || error("unsorted `idxs` vector"))
        length(data) == idxs[end] || error("length of `data` different " * 
                                           "from last element of `idxs`")
        idxs[1] == 0 || error("first element of `idxs` must be zero")
        new(data, idxs, true, 0)
    end
end
HVector{T, S}(data::Vector{T}, idxs::Vector{S}, chksorted::Bool=true) = 
    HVector{T, S}(data, idxs, chksorted) 

eltype{T}(hx::HVector{T}) = T
idxtype{T, S}(hx::HVector{T, S}) = S
size(hx::HVector) = (length(hx), )
length(hx::HVector) = length(hx.idxs) - 1
getindex{T, S}(hx::HVector{T, S}, i) = 
    HTuple(hx, hx.idxs[i]+one(S), hx.idxs[i+1])

# push a full vector - only works if storage is locked
function push!{T, S}(hx::HVector{T, S}, x::AbstractVector{T})
    !(islocked(hx)) && error("HVector is unlocked. Cannot push new array!") 
    # this triggers a bug in append, so we enforce the eltype of `x` to `T`
    append!(hx.data, x)
    push!(hx.idxs, hx.idxs[end] + S(length(x)))
    hx
end

# ~~~ locking mechanism to allow pushing single values ~~~
islocked(hx::HVector) = hx.locked
unlock(hx::HVector) = (hx.pushed = 0; hx.locked = false; nothing)
lock(hx::HVector) = (hx.locked = true; 
                    hx.pushed != 0 && push!(hx.idxs, hx.idxs[end] + hx.pushed); 
                    nothing)

# push a single value
function push!{T}(hx::HVector{T}, x::T)
    islocked(hx) && error("HVector is locked. Cannot push a new value!") 
    push!(hx.data, x)
    hx.pushed += 1
    hx
end

# macro - could be improved as it now requires the hx argument
macro unlocked(hx, expr)
    quote 
        unlock($(esc(hx)))
        $(esc(expr))
        lock($(esc(hx)))
    end
end

# ~~~ HTuple ~~~
immutable HTuple{T<:Number, S<:Integer} <: AbstractVector{T}
    hx::HVector{T, S}
    start::Int
    stop::Int
end
HTuple{T, S}(hx::HVector{T, S}, start::Integer, stop::Integer) = 
    HTuple{T, S}(hx, start, stop)

eltype{T}(x::HTuple{T}) = T
size(x::HTuple) = (length(x), )
length(x::HTuple) = x.stop - x.start + 1
getindex(x::HTuple, i::Integer) = x.hx.data[x.start + i - 1]

end