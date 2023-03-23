module TypedMemo
		
		
export @cached, get_all_caches, get_cache, get_the_cache
export reset_cache!, reset_all_caches!
export ArrayDict, OffsetArrayDict

using MacroTools
using MacroTools: postwalk


const caches = IdDict()


get_all_caches(fun) = get(caches, fun, nothing)

function get_cache(fun, arg_types)
	c = get_all_caches(fun)
	if c == nothing
		return nothing
	end
	get(c, arg_types, nothing)
end

function get_the_cache(fun)
	fun_caches = get_all_caches(fun) 
 	if fun_caches != nothing 
	 	cache = fun_caches |> values |> collect
	 	if length(cache) == 1
			return cache[1]
		end
	end
	nothing
end

function reset_cache!(fun, arg_types)
	c = get_cache(fun, arg_types)
	if c != nothing
		empty!(c)
	end
	c
end

function reset_all_caches!(fun)
	cs = get_all_caches(fun)
	if cs != nothing
		empty!.(values(cs))
	end
	nothing
end


struct Closure{F,A} <: Function
   f::F
   args::A
end
(x::Closure)() = x.f(x.args...)


function process_dict_t_expr(dict_t, args)
	#println(dict_t)
	#println(args)
    if typeof(dict_t) == Symbol
        return :($dict_t{Tuple{$(args...)}, ret_type}), false
    end
    
    splat_args = false
    dict_expr = postwalk(dict_t) do d
        if @capture(d, @ARGS()...) 
            splat_args = true
            :(($(args...),)...)
        else
            d
        end
    end
    dict_expr = postwalk(d -> (@capture(d, @ARGS()) ? :(Tuple{$(args...)}) : d), dict_expr) 
    dict_expr = postwalk(d -> (@capture(d, @RET()) ? :ret_type : d), dict_expr) 
    
    (isexpr(dict_expr, :call) ? :(() -> $dict_expr) : dict_expr), splat_args
end


"""
Dict
Dict{@ARGS(), @RET()}
Dict{@ARGS(), @RET()}()
VectorDict{@ARGS()...}(undef=-1)
VectorDict{@ARGS()...}
"""
macro cached(a1, a2 = nothing, a3 = nothing)
    dict_t = select = nothing
    if a2 == nothing 
        fun = a1
    elseif a3 == nothing
        fun = a2
        dict_t = a1
    else
        fun = a3
        dict_t = a1
        select = a2
    end

    split_fun = splitdef(fun)
    args = split_fun[:args]
    
        # nothing selected, all args are part of the key
    if select == nothing
        select = args
    else
		# nicer to not require ( ,) around single args
		if isexpr(select, Symbol)
			select = Expr(:tuple, select)
		end
        if ! isexpr(select, :vect, :tuple) ||
		    (!isempty(select.args) &&
		    any(x->typeof(x)!=Symbol, select.args))
			error("'$select': argument selector has to be a tuple or vector of variable names")
		end
        
        select = select.args
    end

    if dict_t == nothing
        dict_t = :(IdDict)
    end
    
    # replace type tags, add type parameters if necessary
    dict_t, splat_args = process_dict_t_expr(dict_t, select)
    
    fname = split_fun[:name]
    newfname = gensym(string(fname))
    split_fun[:name] = newfname
    
    # needs to be generated here, otherwise quoting gets wonky
    fcall = 
        if splat_args 
            Meta.quot(quote
                    get!(
                        TypedMemo.Closure($newfname, ($(args...),)), 
                        $(Expr(:$, :cache)), 
                        # args need to be selected and splatted for the *cache lookup only*
                        ($(select...),)...)
                end)
        else
            Meta.quot(quote
                    get!(
                        TypedMemo.Closure($newfname, ($(args...),)), 
                        $(Expr(:$, :cache)), 
                        ($(select...),))
                end)
        end

    quote
        # generate actual function
        $(esc(combinedef(split_fun)))
        
        Core.@__doc__ @noinline @generated function $(esc(fname))($(esc.(args)...))
            arg_types = Tuple{$(esc.(args)...)}
            ret_type = Core.Compiler.return_type($(esc(newfname)), arg_types)

            cache = $dict_t()
            get!(caches, $(esc(fname)), IdDict{Any, Any}())[($(esc.(args)...),)] = cache

            $fcall
        end
    end
end


struct ArrayDict{T, N}
	data :: Array{T, N}
	undefined :: T
end

function ArrayDict{T}(size, undefined = typemax(T)) where {T} 
	ArrayDict(fill(undefined, size), undefined)
end

function Base.get!(def_f, ad :: ArrayDict, key)
	if ad.data[key...] != ad.undefined
		return ad.data[key...]
	end
	
	ad.data[key...] = def_f()
end


Base.empty!(ad :: ArrayDict) = (fill!(ad.data, ad.undefined); ad)


struct OffsetArrayDict{T, N, O}
	data :: Array{T, N}
	undefined :: T
	offset :: O
end

@generated function get_offset(min_tuple)
	n = min_tuple.parameters |> length
	if n > 0
		t = min_tuple.types[1]
		:(($(ones(t, n)...),) .- min_tuple )
	else
		:(1 - min_tuple)
	end
end

function OffsetArrayDict{T}(size, offset, undefined = typemax(T)) where {T} 
	OffsetArrayDict(fill(undefined, size), undefined, get_offset(offset))
end

function Base.get!(def_f, ad :: OffsetArrayDict, key)
	idx = key .+ ad.offset
	if ad.data[idx...] != ad.undefined
		return ad.data[idx...]
	end
	
	ad.data[idx...] = def_f()
end


Base.empty!(ad :: OffsetArrayDict) = (fill!(ad.data, ad.undefined); ad)

end
