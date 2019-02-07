use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :top5, Top5Web.Endpoint,
  secret_key_base: "aV9yNClYyohh7WsUB4Dk1Hp9jxANbx7rVWH+PnXgQmtFDXk20BwDFFA1BCR2aPgD"

# Configure your database
config :top5, Top5.Repo,
  username: "postgres",
  password: "postgres",
  database: "top5_prod",
  pool_size: 15
