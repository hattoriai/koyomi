import Config

if config_env() == :dev do
  # The picker bundles. NODE_PATH is unset: the bundles never pick up a
  # package from deps/.
  esbuild_args = ~w(
    src/index.ts
    --bundle
    --minify
    --target=es2020
    --external:phoenix
    --external:phoenix_live_view
  )

  config :esbuild,
    version: "0.28.2",
    koyomi_esm: [
      args: esbuild_args ++ ~w(--format=esm --outfile=../priv/static/koyomi.esm.js),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => nil}
    ],
    koyomi_cjs: [
      args: esbuild_args ++ ~w(--format=cjs --outfile=../priv/static/koyomi.cjs.js),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => nil}
    ]
end

if config_env() == :test do
  config :logger, level: :warning
  config :phoenix, :json_library, JSON
  config :elixir, :time_zone_database, Tz.TimeZoneDatabase

  config :koyomi, KoyomiTest.Endpoint,
    secret_key_base: String.duplicate("koyomi-test-secret-key-base-", 4),
    live_view: [signing_salt: "koyomi-test-salt"],
    pubsub_server: KoyomiTest.PubSub,
    render_errors: [formats: [html: KoyomiTest.ErrorHTML], layout: false],
    server: false
end
