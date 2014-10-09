@require "Response" Response
@require "Request" Request
@require "router" @route
@require "server" start

router = @route begin
  @route("hit") do r::Request
    Response(200, "Handled upstream")
  end
end

function downstream(r::Request)
  Response(200, "Handled downstream")
end

start(router(downstream), 8000)
