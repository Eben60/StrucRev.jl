module MainTests

using StrucRev
using Test

function istypedglobal(m, v)
    isdefined(m, v) || return false
    getproperty(m, v) isa Function && return false
    return Core.get_binding_type(m, v) != Any
end

struct F0
    x::Int
end

@strev struct F3
    x::F0
end
  
@strev mutable struct F4
    y
end

@strev begin 
    struct F5
        xx::F0
    end
    F5(x::Number) = F5(F0(x))
    F5(x::String) = F5(F0(parse(Int, x)))
end

@strev struct F6
    x1
    x2::F0
    F6(x1, x2::Int) = new(x1, F0(x2))
end

@strev abstract type A1 <: Number end
@strev abstract type A2 <: A1 end

@strev primitive type I08 <: A2 8 end
@strev primitive type I16 16 end

@strev struct F7 <: A2
    x
end

@strev begin
    struct F8{T, S} <: A1 where T <: Real where S <: AbstractString
        r::T
        s::S
    end
    F8(x::Real) = F8(x, repr(x))
end

@strev struct F9{T, S} <: A1 where T <: Real where S <: AbstractString
    r::T
    s::S
end

@strev mutable struct F1
    a::Int
    const b::Float64
end

@strev begin 
    @kwdef struct F10{T}
        a::T = 1
        b::T = 2
        c::T
    end
end

@strev const x9 = 9 
@strev const x10 = 2*5 
@strev const x11 = 10 

x11 = 11

err11 = nothing
try
    global x11 = "12"
    global err11 = false
catch
    global err11 = true
end

@testset "StrucRev" begin

@test F1 === StrucRev_F1.F1
@test F3 === StrucRev_F3.F3
@test F4 === StrucRev_F4.F4
@test F5 === StrucRev_F5.F5
@test F10 === StrucRev_F10.F10
@test I08 === StrucRev_I08.I08
@test I16 === StrucRev_I16.I16
@test A1 === StrucRev_A1.A1
@test A2 === StrucRev_A2.A2

s1 = F1(1, 2.0)
@test s1.a == 1
@test s1.b == 2.0
@test_throws ErrorException s1.b = 3.0

s3 = F3(F0(3))
@test s3.x.x == 3
s4 = F4(4)
@test s4.y == 4
s4.y = 44
@test s4.y == 44

s5 = F5(F0(5))
@test s5.xx.x == 5

s5a = F5(5)
s5b = F5("5")
@test s5 == s5a == s5b

s6 = F6(6, 7)
@test s6.x1 == 6
@test s6.x2.x == 7

s7 = F7(7.0)
@test s7.x == 7.0
@test s7 isa Number
@test s7 isa A1
@test s7 isa A2
@test A2 <: A1
@test A2 <: Number

@test I08 <: A2

s8 = F8(4, "4")
s8a = F8(4)
@test s8 == s8a

s9 = F9(3, "3")
@test s9.r == 3
@test s9.s == "3"

s10a = F10(1, 2, 3)

@test s10a.a == 1
@test s10a.b == 2
@test s10a.c == 3

s10b = F10(;a=1, b=2, c=3)
s10c = F10(; c=3)

@test s10a == s10b == s10c

@test x9 == 9
@test x10 == 10
@test x11 == 11

@test istypedglobal(@__MODULE__, :x9)
@test istypedglobal(@__MODULE__, :x10)

# @test_throws MethodError 
@test isdefined(@__MODULE__, :x9)
@test err11

end # testset

end # module
