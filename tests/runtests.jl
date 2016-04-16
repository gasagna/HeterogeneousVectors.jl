using Base.Test
using HVectors


# test pushing arrays
let xs = HVector{Float64}()
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
let xs = HVector{Float64}()
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
let xs = HVector{Float64}()
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
let xs = HVector{Float64}()

    @unlocked xs for i = 1:5
        push!(xs, Float64(i))
    end

    @test islocked(xs) == true
    @test length(xs) == 1
end

# test print
let xs = HVector{Int64}()
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