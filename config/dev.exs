use Mix.Config

config :logger,
       backends: [{FlexLogger, :logger_name},
                  {FlexLogger, :logger_name2}]


config :logger, :logger_name,
       logger: LoggerFileBackend,
       path: "/tmp/foo.log",
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [module: Foo, level: :info]
       ],
       format: "DEV $message" # logger specific configuration


config :logger, :logger_name2,
       logger: :console,
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [module: Bar, level: :info],
       ],
       format: "BAR $message" # logger specific