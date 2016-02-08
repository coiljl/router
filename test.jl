@require "." create! Router Request @route router

test("abstract matches") do
  child = create!(router, "users/:id")
  @test isa(child, Router)
  @test match(router, "users/1") == (child, ["1"])
  @test child === create!(router, "/users/:id")
end

test("concrete matches") do
  child = create!(router, "users/admin")
  @test isa(child, Router)
  @test match(router, "users/admin") == (child, AbstractString[])
  @test child === create!(router, "/users/admin")
end

test("no match") do
  @test match(router, "wtf/ur/kidding") == nothing
end

test("@route") do
  @route(router, "user/:(\\d+)") do ::Request{:GET}, id::Int id end
  @route(router, "user/:(\\d+)") do ::Request{:PUT}, id::UTF8String id end
  @route(router, "user/:(\\d+)") do ::Request, id id end
  @test router(Request(IOBuffer("GET user/1"))) == 1
  @test isa(router(Request(IOBuffer("GET /user/1"))), Int)
  @test router(Request(IOBuffer("PUT user/1"))) == "1"
  @test isa(router(Request(IOBuffer("PUT /user/1"))), UTF8String)
  @test router(Request(IOBuffer("DELETE user/1"))) == "1"
  @test isa(router(Request(IOBuffer("DELETE /user/1"))), SubString)
end
