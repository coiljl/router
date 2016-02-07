@require "." create! Router Request @route

base = Router()

test("abstract matches") do
  child = create!(base, "users/:id")
  @test isa(child, Router)
  @test match(base, "users/1") == (child, ["1"])
  @test child === create!(base, "/users/:id")
end

base.concrete
test("concrete matches") do
  child = create!(base, "users/admin")
  @test isa(child, Router)
  @test match(base, "users/admin") == (child, AbstractString[])
  @test child === create!(base, "/users/admin")
end

test("no match") do
  @test match(base, "wtf/ur/kidding") == nothing
end

test("@route") do
  route = @route begin
    @route("user/:(\\d+)") do ::Request{:GET}, id::Int id end
    @route("user/:(\\d+)") do ::Request{:PUT}, id::UTF8String id end
    @route("user/:(\\d+)") do ::Request, id id end
  end
  @test route(Request(IOBuffer("GET user/1"))) == 1
  @test isa(route(Request(IOBuffer("GET /user/1"))), Int)
  @test route(Request(IOBuffer("PUT user/1"))) == "1"
  @test isa(route(Request(IOBuffer("PUT /user/1"))), UTF8String)
  @test route(Request(IOBuffer("DELETE user/1"))) == "1"
  @test isa(route(Request(IOBuffer("DELETE /user/1"))), SubString)
end
