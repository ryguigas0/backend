# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :phoenix, :json_library, Jason

config :cambiatus, env: Mix.env()

config :ex_aws,
  s3: [
    scheme: "https://",
    host: "cambiatus-uploads.s3.amazonaws.com",
    region: "us-east-1"
  ]

# Configures the endpoint
config :cambiatus, CambiatusWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Tbckg2miZcMoSPt4L5vSwyjKG6VHCwbg3MBp+e/tszbcvQ/a4HJOI3G4/IRYwo8m",
  render_errors: [view: CambiatusWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: Cambiatus.PubSub

config :cambiatus,
  ecto_repos: [Cambiatus.Repo]

config :cambiatus, Cambiatus.Repo, pool_size: 15

config :cambiatus, Cambiatus.Mailer,
  sender_email: "no-reply@cambiatus.com",
  adapter: Swoosh.Adapters.Sendinblue,
  api_key: System.get_env("SENDINBLUE_KEY")

config :sentry,
  dsn: "https://cf10887ac4c346ebb26cbc3522578465@sentry.io/1467632",
  included_environments: ~w(prod staging dev),
  environment_name: Mix.env()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
