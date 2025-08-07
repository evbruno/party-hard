import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :party_hard, PartyHardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "SlqQ4b5Lce0NZtjPuSuLcx64P8zP5XrgJ5BEHuu42nVffYwuihk+zhRgbX0yewAd",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
