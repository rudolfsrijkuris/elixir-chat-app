# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :chat_api,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :chat_api, ChatApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [
      html: {ChatApiWeb.ErrorHTML, [layout: {ChatApiWeb.Layouts, :root}]},
      json: ChatApiWeb.ErrorJSON
    ],
    layout: false
  ],
  pubsub_server: ChatApi.PubSub,
  live_view: [signing_salt: "d1prTZkJ"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :chat_api, ChatApi.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Tailwind (built CSS so LiveView patches are styled)
config :tailwind,
  version: "4.1.12",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Esbuild for LiveView assets (use 0.24.2 - 0.24.9 not published for darwin-arm64)
config :esbuild,
  version: "0.24.2",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
