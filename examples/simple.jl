@require "github.com/coiljl/server" Request Response serve
@require ".." @route

const users = [
  Dict("name"=>"jake"),
  Dict("name"=>"gazz")
]

const router = @route begin
  @route("user/:(\\d+)") do r::Request{:GET}, id::Int
    name = users[id]["name"]
    Response(200, "User #$id's name is $name")
  end

  @route("user/:(\\d+)") do r::Request{:PUT}, id::Int
    if length(users) < id resize!(users, id) end
    users[id] = Dict("name"=>r.uri.query["name"])
    Response(200)
  end
end

const server = serve(router, 8000)
println("Server running at http://localhost:8000")
println("try `curl -X PUT :8000/user/1?name=jeff`")
println("then `curl -X GET :8000/user/1`")
wait(server)
