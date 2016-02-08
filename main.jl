@require "github.com/coiljl/server" Request Response serve verb
@require "github.com/jkroso/coerce.jl" coerce

immutable Router
  handler::Function
  concrete::Dict{AbstractString,Router}
  regexs::Vector{Pair{Regex,Router}}
end

Router(path::AbstractString) =
  Router(@eval(function $(gensym(path))() end),
         Dict{AbstractString,Router}(),
         Pair{Regex,Router}[])

"""
The root router for use by applications only
"""
const router = Router("/")

"""
Support use with downstream middleware
"""
Base.call(router::Router, next::Function) =
  function(req::Request)
    res = router(req)
    403 < res.status < 406 ? next(req) : res
  end

"""
Dispatch a Request to a handler on router
"""
Base.call(router::Router, req::Request) = begin
  m = match(router, req.uri.path)
  m === nothing && return Response(404, "invalid path")
  node, params = m

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
  verbs = map(methods(r.handler)) do method
    args_types = method.sig.parameters
    isempty(args_types) && return "method"
    string(args_types[1].parameters[1])
  end
  setdiff(unique(verbs), ["method"])
end

"""
Find `Router` nodes on `r` matching the path `p`

If it matches on any abstract paths the concrete values
of those path segments will be returned in a `AbstractString[]`
"""
Base.match(router::Router, p::AbstractString) = begin
  captures = AbstractString[]
  for segment in split(p, '/'; keep=false)
    if haskey(router.concrete, segment)
      router = router.concrete[segment]
    else
      i = findfirst(p -> ismatch(p[1], segment), router.regexs)
      i === 0 && return nothing
      regex, router = router.regexs[i]
      m = match(regex, segment)
      m != nothing && !isempty(m.captures) && push!(captures, m.captures...)
    end
  end
  (router, captures)
end

"""
Define a route for `path` on `node`
"""
create!(node::Router, path::AbstractString) =
  reduce(node, split(path, '/'; keep=false)) do node, segment
    m = match(r"^:[^(]*(?:\(([^\)]+)\))?$"i, segment)
    if m === nothing
      get!(node.concrete, segment, Router(path))
    else
      create!(node, to_regex(m.captures[1]))
    end
  end

create!(node::Router, path::Regex) = begin
  i = findfirst(t -> t[1].pattern == path.pattern, node.regexs)
  if i == 0
    push!(node.regexs, path => Router(path |> string))[end][2]
  else
    node.regexs[i][2]
  end
end

to_regex(s::Void) = r"^(.*)$"
to_regex(s::AbstractString) = Regex("^($s)\$", "i")

param_type(p::Expr) = eval(p.args[2])
param_type(p::Symbol) = Any

param_name(p::Expr) = p.args[1]
param_name(p::Symbol) = p

"""
Syntax sugar for defining routes so you don't have to bother naming your route
handlers. Instead they will take on the name of the path.

```julia
@route(router, "/user/:id") do req::Request{:GET}, id::Int
  Response(200, users[id])
end

@route(router, "/user/:id") do req::Request{:PUT}, id::Int
  users[id] = req.uri.query.name
  Response(200)
end
```

Note that this only creates one route and one handler but this handler will
have two methods. One for `GET` requests and one for `PUT` requests
"""
macro route(fn::Expr, router::Symbol, path)
  params = fn.args[1].args
  types = map(param_type, params[2:end])
  names = map(param_name, params[2:end])
  params = [params[1], names...]
  coersion = map(types, names) do Type, name
    :($name = $(Expr(:call, coerce, Type, name)))
  end
  body = fn.args[2].args
  child = gensym()
  esc(quote
    $child = $(create!)($router, $path)
    $child.handler($(params...)) = begin
      $(coersion...)
      $(body...)
    end
  end)
end
