# FlexLogger

A flexible logger backend intended to be used with Elixir's `Logger` to add module specific log levels.

## Installation

The package can be installed by adding `flex_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flex_logger, "~> 0.1.0"}
  ]
end
```

## Usage

Full documentation can be found at [https://hexdocs.pm/flex_logger](https://hexdocs.pm/flex_logger).

Following is a quick example of how to add FlexLogger to your logging configuration

```elixir
config :logger,
       backends: [{FlexLogger, :foo_file_logger},
                  {FlexLogger, :bar_console_logger},
                  {FlexLogger, :default_logger}]

config :logger, :foo_file_logger,
       logger: LoggerFileBackend, # The actual backend to use (for example :console or LoggerFileBackend)
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [application: :my_app, module: Foo, level: :info] # available keys are :application, :module, :function
       ],
       path: "/tmp/foo.log", # logger specific configuration
       format: "FOO $message" # logger specific configuration


config :logger, :bar_console_logger,
       logger: :console,
       default_level: :off, # this is the loggers default level
       level_config: [ # override default levels
         [application: :some_app, module: Bar, level: :info],
       ],
       format: "BAR $message" # logger specific

config :logger, :default_logger,
       logger: :console,
       default_level: :debug, # this is the loggers default level
       level_config: [ # override default levels
         [application: :some_app, module: Bar, level: :off], # not Bar and
         [application: :my_app, module: Foo, level: :off], # not Foo
       ],
       format: "DEFAULT $message" # logger specific
```

## License

FlexLogger source code is released under MIT License.

Check LICENSE file for more information.

