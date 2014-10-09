@require "Request" Request verb
@require "Response" Response
@require "coerce" coerce

type Router
  concrete::Dict{String,Router}
  Abstract::Vector{(Regex,Router)}
  handler::Function
  Router(c=Dict{String,Router}(), a=(Regex,Router)[]) = new(c, a)
end

##
# Support use with downstream middleware
#
function handle(router::Router, next::Function)
  function(req::Request)
    res = handle(router, req)
    403 < res.status < 406 ? next(req) : res
  end
end

##
# Dispatch a Request to a handler on router
#
function handle(router::Router, req::Request)
  m = match(router, req.uri.path)
  m === nothing && return Response(404, "invalid path")
  node, params = m

  isdefined(node, :handler) || return Response(404, "incomplete path")

  signature = tuple(typeof(req), fill(Any, length(params))...)
  if method_exists(node.handler, signature)
    node.handler(req, params...)
  else
    Response(verb(req) == "OPTIONS" ? 204 : 405, # OPTIONS support
             ["Allow" => join(allows(node), ", ")])
  end
end

function allows(r::Router)
  !isdefined(r, :handler) && return String[]
  map(methods(r.handler)) do method
    string(method.sig[1].parameters[1])
  end |> unique
end

##
# Find Router nodes on `r` matching the path `p`
#
# If it matches on any abstract paths the concrete values
# of those path segments will be returned in a `String[]`
#
function Base.match(r::Router, p::String)
  captures = String[]
  for seg in split(p, '/', false)
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

##
# Define a route for `path` on `node`
#
function create!(node::Router, path::String)
  reduce(node, split(path, '/', false)) do node, segment
    m = match(r"^:[^(]*(?:\(([^\)]*)\))?$"i, segment)
    if m === nothing
      get!(node.concrete, segment, Router())
    else
      # verbose because `::Regex == ::Regex` is broken
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
end

to_regex(s::Nothing) = r"(.*)"
to_regex(s::String) = Regex(s, "i")

const stack = Router[]

##
# Syntax sugar for defining routes
#
# If you pass an Expr it will define a group of routes and return
# a function which dispatches Requests to those routes
#
# If you pass both a Function Expr and a String it will define a new
# route with the Function Expr as the handler. Any parameters defined
# in the path will be coerced to the types declared in the Function
# Expr. This form is only valid inside the previous form
#
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
      @assert !isempty(stack) "@route(::Function,::String) only valid within @route(::Expr)"
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
