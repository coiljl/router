@require "Response" Response
@require "Request" Request
@require "router" @route
@require "server" start

users = {
  ["name"=>"jake"],
  ["name"=>"gazz"]
}

router = @route begin
  @route("user/:(\\d+)") do r::Request{:GET}, id::Int
    name = users[id]["name"]
    Response(200, "User #$id's name is $name")
  end

  @route("user/:(\\d+)") do r::Request{:PUT}, id::Int
    if length(users) < id resize!(users, id) end
    users[id] = ["name"=>r.uri.query["name"]]
    Response(200)
  end
end

start(router, 8000)
