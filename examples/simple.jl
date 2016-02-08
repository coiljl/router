@require "github.com/coiljl/server" Request Response serve
@require ".." router @route

const users = [
  Dict("name"=>"jake"),
  Dict("name"=>"gazz")
]

@route(router, "/") do r::Request{:GET}
  text = """
    try `curl -X PUT :8000/user/1?name=jeff`
    then `curl -X GET :8000/user/1`
  """
  Response(200, text)
end

@route(router, "user/:(\\d+)") do r::Request{:GET}, id::Int
  name = users[id]["name"]
  Response(200, "User #$id's name is $name")
end

@route(router, "user/:(\\d+)") do r::Request{:PUT}, id::Int
  if length(users) < id resize!(users, id) end
  users[id] = Dict("name"=>r.uri.query["name"])
  Response(200)
end

const server = serve(router, 8000)
println("Server running at http://localhost:8000")
wait(server)
