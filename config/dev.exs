use Mix.Config

config :logger,
       backends: [{FlexLogger, :foo_file_logger},
                  {FlexLogger, :bar_console_logger},
                  {FlexLogger, :default_logger}]

config :logger, :foo_file_logger,
       logger: LoggerFileBackend, # The actual backend to use (for example :console or LoggerFileBackend)
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [module: Foo, level: :info] # available keys are :application, :module, :function
       ],
       path: "/tmp/foo.log", # backend specific configuration
       format: "FOO $message" # backend specific configuration


config :logger, :bar_console_logger,
       logger: :console,
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [module: Bar, level: :info],
       ],
       format: "BAR $message" # backend specific

config :logger, :default_logger,
       logger: :console,
       default_level: :debug, # this is the loggers default level
       level_config: [ # override default levels
         [module: Bar, level: :off], # not Bar and
         [module: Foo, level: :off], # not Foo
       ],
       format: "DEFAULT $message" # backend specific