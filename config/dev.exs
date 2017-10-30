use Mix.Config

config :logger,
       backends: [{FlexLogger, :dev_backend}]


config :logger, :dev_backend,
       logger: Logger.Backends.Console,
       level: :error,
       level_config: [
         [module: :foobar, level: :info],
         [module: :test, level: :debug]
       ],
       path: "test/logs/error.log",
       format: "DEV $message"
