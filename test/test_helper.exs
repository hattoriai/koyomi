{:ok, _pid} = Phoenix.PubSub.Supervisor.start_link(name: KoyomiTest.PubSub)
{:ok, _pid} = KoyomiTest.Endpoint.start_link()
# The :build tests run `mix koyomi.build` (npm and network on the first
# run) and `mix hex.build`: `mix test --include build`.
ExUnit.start(exclude: [:build])
