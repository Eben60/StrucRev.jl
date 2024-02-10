module StrucRev
using MacroTools
using MacroTools: prewalk, namify 

const packagename = string(@__MODULE__)

# https://discourse.julialang.org/t/get-all-names-accessible-from-a-module/98492/10
extract_variables!(s::Symbol; _names, _mod) = isdefined(_mod, s) && 
    !(!(parentmodule(_mod) == Main) && isdefined(Main, s)) && 
    !isdefined(Base, s) && 
    push!(_names, s)

extract_variables!(x; kwargs...) = nothing

function extract_variables!(ex::Expr; kwargs...)
    if ex.head === :.
        extract_variables!(ex.args |> first; kwargs...)
    else
        foreach(x -> extract_variables!(x; kwargs...), ex.args)
    end
    return nothing
end

function extract_variables(ex, m)
    _names = Set{Symbol}()
    extract_variables!(ex; _names, _mod=m)
    return sort(collect(_names))
end

function make_usings(ex, fname, m)
    vars = extract_variables(ex, m)
    setdiff!(vars, [fname])
    varsstr = join(vars, ", ")    
    exstr = isempty(vars) ? "" : "using $m: $varsstr"
    return Meta.parse(exstr)
end

getstructnames!(x, _names) = nothing

function getstructnames!(ex::Expr, _names)
    if ex.head == :struct
        sname = namify(ex.args[2]) 
        push!(_names, sname)
    elseif ex.head in (:abstract, :primitive)
        sname = namify(ex.args[1]) 
        push!(_names, sname)       
    else
        foreach(x -> getstructnames!(x, _names), ex.args)
    end
    return nothing
end

function getstructname(arg)
    _names = Symbol[]
    getstructnames!(arg, _names)
    isempty(_names) && error("Parsing error with @strev - no struct definitions found")
    length(_names) > 1 && error("Parsing error with @strev - more than one struct definitions found")
    sname = _names[1]
    return sname
end

function strev_struct(arg, mod)
    fname = getstructname(arg)
    exusings = make_usings(arg, fname, mod)
    blck = Expr(:block, exusings, arg)
    modname = Symbol("$(packagename)_$(fname)")
    wrappermod = Expr(:module, true, modname, blck) 
    modname = wrappermod.args[2]
    ex2 = :($fname = $modname.$fname)
    ex3 = Expr(:toplevel, wrappermod, ex2)
    return esc(ex3) 
end

function strev_const(arg)
    arg = prewalk(rmlines, arg)
    head = arg.head
    args = arg.args
    head == :const || error("Parsing error with @strev")
    ex = args[1]
    ex.head == :(=) || error("Parsing error with @strev")
    # https://giordano.github.io/blog/2022-06-18-first-macro/
    q = quote
        local tmp = $(esc(ex.args[2]))
        $(esc(ex.args[1]))::typeof(tmp) = tmp
    end

    return q
end

macro strev(arg)
    mod = __module__
    arg = rmlines(arg)
    if arg.head in (:struct, :block, :abstract, :primitive)
        return strev_struct(arg, mod)
    elseif arg.head == :const 
        return strev_const(arg)       
    else
        error("Parsing error with @strev")
    end
end

export @strev

end # module ModularWF