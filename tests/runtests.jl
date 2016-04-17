using Base.Test
using HVectors

# test constructors
let 
    xs = HVector{Int64, UInt64}()
    @test eltype(xs) == Int64
    @test idxtype(xs) == UInt64

    # from data
    data =  Int64[5, 8, 3, 1, 2, 4]
    idxs = UInt32[0, 2, 5, 6]

    xs = HVector(data, idxs)
    @test eltype(xs) == Int64
    @test idxtype(xs) == UInt32
    @test length(xs) == 3
    @test size(xs) == (3, )
    @test xs[1] == [5, 8]
    @test xs[2] == [3, 1, 2]
    @test xs[3] == [4]

    # from too long indices data
    data =  Int64[5, 8, 3, 1, 2, 4]
    idxs = UInt32[0, 2, 5, 6, 7]
    @test_throws ErrorException xs = HVector(data, idxs)

    # first index must be zero
    data =  Int64[5, 8, 3, 1, 2, 4]
    idxs = UInt32[1, 2, 5, 6]
    @test_throws ErrorException xs = HVector(data, idxs)

    # from unsorted indices
    data =  Int64[5, 8, 3, 1, 2, 4]
    idxs = UInt32[5, 2, 7, 6]
    @test_throws ErrorException xs = HVector(data, idxs)

    # from unsorted indices, does not throw
    data =  Int64[5, 8, 3, 1, 2, 4]
    idxs = UInt32[0, 2, 7, 6]
    xs = HVector(data, idxs, false)

end



# test pushing arrays
let xs = HVector{Float64, UInt32}()
    push!(xs, [1.0])
    push!(xs, [1.0, 2.0])
    push!(xs, [1.0, 2.0, 3.0])
    push!(xs, [1.0, 2.0, 3.0, 4.0])

    @test length(xs) == 4
    @test size(xs) == (4, )
    @test eltype(xs) == Float64

    # test indexing
    for i = 1:4
        x = xs[i]
        @test length(x) == i
        @test x == collect(1.0:i)
    end

    # test indexing of PolyElement
    x = xs[end]
    for i = 1:4
        @test x[i] == Float64(i)
    end
end

# test locking mechanism
let xs = HVector{Float64, UInt32}()
    @test islocked(xs) == true
    unlock(xs)
    @test islocked(xs) == false
    lock(xs)
    @test islocked(xs) == true
    
    # pushing single value fails when storage is locked
    @test_throws ErrorException push!(xs, 1.0)
    
    # but works for arrays as normal
    push!(xs, [1.0, 2.0])
    @test length(xs) == 1
    
    # however you cannot push a vector if storage is unlocked
    unlock(xs)
    @test_throws ErrorException push!(xs, [1.0, 2.0])
end

# test pushing values
let xs = HVector{Float64, UInt32}()
    # push one first
    unlock(xs)
    push!(xs, 1.0); push!(xs, 2.0); push!(xs, 3.0)
    lock(xs)

    # push another one
    unlock(xs)
    push!(xs, 4.0); push!(xs, 5.0); push!(xs, 6.0)
    lock(xs)
    
    @test length(xs) == 2
    @test xs[1] == [1, 2, 3]
    @test xs[2] == [4, 5, 6]
end

# test macro
let xs = HVector{Float64, UInt32}()

    @unlocked xs for i = 1:5
        push!(xs, Float64(i))
    end

    @test islocked(xs) == true
    @test length(xs) == 1
end

# test print
let xs = HVector{Int64, UInt32}()
    srand(5)
    for j = 1:2
        @unlocked xs for i = 1:rand(2:5)
            push!(xs, i)
        end
    end
    io = IOBuffer()
    println(io, xs)
    @test takebuf_string(io) == "[[1,2],[1,2,3,4]]\n"
end