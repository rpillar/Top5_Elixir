# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :top5,
  ecto_repos: [Top5.Repo]

config :top5, Top5.Accounts.Guardian,
  issuer: "top5",
  secret_key: "M2nlkRbPZ3WJ+TBCDv8A/QDZZsWP1XAh9sy5/pff2L37bAcoCjQiV1/kPJLfZoSN"

# Configures the endpoint
config :top5, Top5Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "cPJXDl1PjOTxmbTm0RII9BHAHfYgGfTceOuQ+XkcQbsmqise6Er8k/XVR3XUfw9t",
  render_errors: [view: Top5Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Top5.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
