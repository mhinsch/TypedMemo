using TypedMemo
using Test


bla1(x) = x * x
bla2(x, y) = x * y
bla3(x, y, z) = x * y * z

check(res) = typeof(res) <: Function

@testset "Syntax" begin

	@test (@cached bla(x) = bla1(x)) |> check 
	@test (@cached Dict bla(x) = bla1(x)) |> check 
	@test (@cached Dict() bla(x) = bla1(x)) |> check 
	
	@test (@cached Dict{@ARGS(), @RET()} bla(x) = bla1(x)) |> check 
	@test (@cached Dict{@ARGS()..., @RET()} bla(x) = bla1(x)) |> check 
	
	@test (@cached Dict (x,) bla(x, y) = bla1(x)) |> check 
	@test (@cached Dict{@ARGS(), @RET()} (x,) bla(x, y) = bla1(x)) |> check 
	@test (@cached Dict{@ARGS()..., @RET()} (x,) bla(x, y) = bla1(x)) |> check 

	@test (@cached Dict (x,z) bla(x, y, z) = bla1(x)) |> check 
	@test (@cached Dict{@ARGS(), @RET()} (x,z) bla(x, y, z) = bla1(x)) |> check 
	
end


@cached bla_1(x) = bla1(x)
@cached Dict bla_2(x) = bla1(x)
@cached Dict() bla_3(x) = bla1(x)

@cached Dict{@ARGS(), @RET()} bla_4(x) = bla1(x)
@cached Dict{@ARGS()..., @RET()} bla_5(x) = bla1(x)

@cached Dict (x,) bla_6(x, y) = bla1(x)
@cached Dict{@ARGS(), @RET()} (x,) bla_7(x, y) = bla1(x)
@cached Dict{@ARGS()..., @RET()} (x,) bla_8(x, y) = bla1(x)

@cached Dict (x,z) bla_9(x, y, z) = bla1(x)
@cached Dict{@ARGS(), @RET()} (x,z) bla_10(x, y, z) = bla2(x, y)


@testset "Function generation" begin
	@test bla_1(1) == bla1(1)
	@test bla_2(1) == bla1(1)
	@test bla_3(1) == bla1(1)
	
	@test bla_4(1) == bla1(1)
	@test bla_5(1) == bla1(1)
	
	@test bla_6(10, 11) == bla1(10)
	@test bla_7(10, 11) == bla1(10)
	@test bla_8(10, 11) == bla1(10)

	@test bla_9(10, 11, 12) == bla1(10)
	@test bla_10(10, 11, 12) == bla2(10, 11)
end


@testset "Cache types" begin
	@test typeof(get_the_cache(bla_1)) == IdDict{Tuple{Int}, Int}
	@test typeof(get_the_cache(bla_2)) == Dict{Tuple{Int}, Int}
	@test typeof(get_the_cache(bla_3)) == Dict{Any, Any}
	
	@test typeof(get_the_cache(bla_4)) == Dict{Tuple{Int}, Int}
	@test typeof(get_the_cache(bla_5)) == Dict{Int, Int}
	
	@test typeof(get_the_cache(bla_6)) == Dict{Tuple{Int}, Int}
	@test typeof(get_the_cache(bla_7)) == Dict{Tuple{Int}, Int}
	@test typeof(get_the_cache(bla_8)) == Dict{Int, Int}
	
	@test typeof(get_the_cache(bla_9)) == Dict{Tuple{Int, Int}, Int}
	@test typeof(get_the_cache(bla_10)) == Dict{Tuple{Int, Int}, Int}
end


@testset "Cache content" begin
	@test get_the_cache(bla_1) == IdDict{Tuple{Int}, Int}((1,) => 1)
	@test get_the_cache(bla_2) == Dict{Tuple{Int}, Int}((1,) => 1)
	@test get_the_cache(bla_3) == Dict{Any, Any}((1,) => 1)
	
	@test get_the_cache(bla_4) == Dict{Tuple{Int}, Int}((1,) => 1)
	@test get_the_cache(bla_5) == Dict{Int, Int}(1 => 1)
	
	@test get_the_cache(bla_6) == Dict{Tuple{Int}, Int}((10,) => 100)
	@test get_the_cache(bla_7) == Dict{Tuple{Int}, Int}((10,) => 100)
	@test get_the_cache(bla_8) == Dict{Int, Int}(10 => 100)
	
	@test get_the_cache(bla_9) == Dict{Tuple{Int, Int}, Int}((10,12) => 100)
	@test get_the_cache(bla_10) == Dict{Tuple{Int, Int}, Int}((10,12) => 110)
end


get_the_cache(bla_1)[(1,)] = 42
get_the_cache(bla_2)[(1,)] = 42
get_the_cache(bla_3)[(1,)] = 42

get_the_cache(bla_4)[(1,)] = 42
get_the_cache(bla_5)[1] = 42

get_the_cache(bla_6)[(10,)] = 42
get_the_cache(bla_7)[(10,)] = 42
get_the_cache(bla_8)[10] = 42

get_the_cache(bla_9)[(10,12)] = 42
get_the_cache(bla_10)[(10,12)] = 42

@testset "Cache retrieval" begin
	@test bla_1(1) == 42
	@test bla_2(1) == 42
	@test bla_3(1) == 42
	
	@test bla_4(1) == 42
	@test bla_5(1) == 42
	
	@test bla_6(10, 11) == 42
	@test bla_7(10, 11) == 42
	@test bla_8(10, 11) == 42

	@test bla_9(10, 11, 12) == 42
	@test bla_10(10, 11, 12) == 42
end


@testset "Misc" begin
	@test bla_1("a") == "aa"
	@test get_the_cache(bla_1) == nothing
	@test length(get_all_caches(bla_1)) == 2
	@test get_cache(bla_1, (String,)) == IdDict{Tuple{String}, String}(("a",) => "aa")
end
