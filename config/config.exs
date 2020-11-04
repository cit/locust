# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#

config :logger, :console,
  level: :error
  #level: :debug

# config :logger,
#   backends: [{LoggerFileBackend, :info},
#              {LoggerFileBackend, :error}]

# config :logger, :info,
#   path: "log/info.log",
#   level: :info

# config :logger, :error,
#   path: "log/error.log",
#   level: :error

config :mldht,
  port: 0,
  ipv4: true,
  ipv4_addr: {0, 0, 0, 0},
  ipv6: false
