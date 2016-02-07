@require "github.com/coiljl/server" Request Response serve
@require ".." @route

router = @route begin
  @route("hit") do r::Request
    Response(200, "Handled upstream")
  end
end

downstream(r::Request) = Response(200, "Handled downstream")

const server = serve(router(downstream), 8000)

println("Server running at http://localhost:8000")
println("try `curl :8000`")
println("then `curl :8000/hit`")
wait(server)
