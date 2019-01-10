# Router

An HTTP Request router

- Automatically parses parameters from the Request's path
- If no routes match it returns a 404
- If the route matches but the method doesn't it returns a 405

```julia
@require "." @route router Request Response

@route "user/:(\\d+)" function(r::Request{:GET}, id::Int)
  Response(200, "getting user #$id")
end

@route "user/:(\\d+)" function(r::Request{:PUT}, id::Int)
  Response(200, "putting user #$id")
end

router(Request(IOBuffer("GET /user/1\r\n\r\n")))
```

And if you already have a function defined you can put it on the router like this:

```julia
@require "github.com/coiljl/static" static
router("/images", static("."))
```
