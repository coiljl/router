@require "github.com/jkroso/HTTP.jl/server" Request Response serve
@require ".." router @route

const users = [
  Dict("name"=>"jake"),
  Dict("name"=>"gazz")
]

@route "/" function(r::Request{:GET})
  Response(200, """
    try `curl -X PUT :8000/user/1?name=jeff`
    then `curl -X GET :8000/user/1`
  """)
end

@route "user/:(\\d+)" function(r::Request{:GET}, id::Int)
  Response(200, "User #$id's name is $(users[id]["name"])")
end

@route "user/:(\\d+)" function(r::Request{:PUT}, id::Int)
  if length(users) < id resize!(users, id) end
  users[id] = Dict("name"=>r.uri.query["name"])
  Response(200)
end

const server = serve(router, 8000)
println("Server running at http://localhost:8000")
wait(server)
