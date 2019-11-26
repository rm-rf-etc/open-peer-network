# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :opn, OPNWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "3wxUFwHMb5HA4R+ecC8SRSnvce6AsivqueJRtEINEWT9XbY4eTn3BjPW5kdbFWkt",
  render_errors: [view: OPNWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: OPN.PubSub, adapter: Phoenix.PubSub.PG2]

config :opn, OPN.Caylir,
  host: "localhost",
  port: 64210,
  json_decoder: {Jason, :decode!, []},
  json_encoder: {Jason, :encode!, []}

# Use `mix guardian.gen.secret` to get a new secret
config :opn, OPN.Guardian,
  issuer: "opn",
  secret_key: "oa7gkgNtpOGiiwHJgArd2DYaT0AiDNW5YHVLyQWm28ATQcOGFj2fPHCC76Q4i6tG"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
