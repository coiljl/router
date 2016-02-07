@require "github.com/coiljl/server" Request Response serve verb
@require "github.com/jkroso/coerce.jl" coerce

type Router
  concrete::Dict{AbstractString,Router}
  Abstract::Vector{Tuple{Regex,Router}}
  handler::Function
  Router(c=Dict{AbstractString,Router}(), a=Tuple{Regex,Router}[]) = new(c, a)
end

"""
Support use with downstream middleware
"""
handle(router::Router, next::Function) =
  function(req::Request)
    res = handle(router, req)
    403 < res.status < 406 ? next(req) : res
  end

"""
Dispatch a Request to a handler on router
"""
handle(router::Router, req::Request) = begin
  m = match(router, req.uri.path)
  m === nothing && return Response(404, "invalid path")
  node, params = m

  isdefined(node, :handler) || return Response(404, "incomplete path")

  if applicable(node.handler, req, params...)
    node.handler(req, params...)
  else
    Response(verb(req) == "OPTIONS" ? 204 : 405, # OPTIONS support
             Dict("Allow" => join(allows(node), ", ")))
  end
end

"""
The list of HTTP methods supported by a `Router`
"""
allows(r::Router) = begin
  !isdefined(r, :handler) && return AbstractString[]
  map(methods(r.handler)) do method
    string(method.sig[1].parameters[1])
  end |> unique
end

"""
Find Router nodes on `r` matching the path `p`

If it matches on any abstract paths the concrete values
of those path segments will be returned in a `AbstractString[]`
"""
Base.match(r::Router, p::AbstractString) = begin
  captures = AbstractString[]
  for seg in split(p, '/'; keep=false)
    if haskey(r.concrete, seg)
      r = r.concrete[seg]
    else
      i = findfirst(r -> ismatch(r[1], seg), r.Abstract)
      i === 0 && return nothing
      r = r.Abstract[i][2]
      push!(captures, seg)
    end
  end
  (r, captures)
end

"""
Define a route for `path` on `node`
"""
create!(node::Router, path::AbstractString) =
  reduce(node, split(path, '/'; keep=false)) do node, segment
    m = match(r"^:[^(]*(?:\(([^\)]*)\))?$"i, segment)
    if m === nothing
      get!(node.concrete, segment, Router())
    else
      r = to_regex(m.captures[1])
      i = findfirst(t -> t[1].pattern == r.pattern, node.Abstract)
      if i === 0
        push!(node.Abstract, (r, Router()))
        node.Abstract[end][2]
      else
        node.Abstract[i][2]
      end
    end
  end

to_regex(s::Void) = r"(.*)"
to_regex(s::AbstractString) = Regex(s, "i")

to_regex("user/:id(\\d+)")

const stack = Router[]

"""
Syntax sugar for defining routes

If you pass a block `Expr` it will define a group of `Route`s and return
a `Function` which dispatches `Request`s to these `Route`s

If you pass both a Function Expr and an `AbstractString` it will define a
new `Route` with the Function Expr as the handler. Any parameters defined
in the path will be coerced to the types declared in the Function
Expr. This form is only valid inside the previous form
"""
macro route(fn::Expr, path...)
  if isempty(path)
    quote
      push!(stack, Router())
      $(map(esc, fn.args)...)
      router = pop!(stack)
      req -> handle(router, req)
    end
  else
    path = path[1]
    sym = symbol("@route\"$path\"")
    params = fn.args[1].args
    types = map(param_type, params[2:end])
    names = map(param_name, params[2:end])
    params = [params[1], names...]
    coersion = map(types, names) do Type, name
      :($name = $(Expr(:call, coerce, Type, name)))
    end
    body = fn.args[2].args
    quote
      @assert !isempty(stack) "@route(::Function,::AbstractString) only valid within @route(::Expr)"
      $(esc(:(function $sym($(params...))
        $(coersion...)
        $(body...)
      end)))
      create!(stack[end], $path).handler = $(esc(sym))
    end
  end
end

param_type(p::Expr) = eval(p.args[2])
param_type(p::Symbol) = Any

param_name(p::Expr) = p.args[1]
param_name(p::Symbol) = p
