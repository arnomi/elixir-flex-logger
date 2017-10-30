defmodule FlexLogger do
  @moduledoc """
  `FlexLogger` is a flexible logger (backend) adds module/application specific log levels to Elixir's `Logger`.

  `FlexLogger` brings the following additions to the table:

    * Configuration of log levels per application, module or even function

    * Possibility of having multiple logger configurations for different applications or modules

  ## Configuration

  `FlexLogger` is configured as a named backend to `Logger`. Following is an example configuration
  of a single `FlexLogger` in combination with a :console logger

       config :logger,
         backends: [{FlexLogger, :logger_name}]

       config :logger, :logger_name,
         logger: :console,
         default_level: :debug, # this is the loggers default level
         level_config: [ # override default levels
           [module: Foo, level: :info]
         ],
         format: "DEV $message" # backend specific configuration

  The configuration for `FlexLogger` as well as the underlying actual log backend are under the
  named config. `FlexLogger` knows the following configuration options:

    * `logger:` The actual logger backend to use. In case of `Logger.Backend.Console` you can also use the :console shortcut.

    * `default_level:` The default log level to use. This should be one of [:off, :debug, :info, :warn, :error]. In addition
      to the standard four log levels the :off level allows to turn of logging for either individual modules or if used
      as default_level to turn of logging per default to then only enable logging for individual modules or applications

    * `level_config:` A list of log level configurations for modules and applications. Each entry should be a keyword list.
      If only a single entry is present the config can be simplified to only a single keyword list like

          level_config: [application: :my_app, level: :info]

      Possible configuration options are `:application`, to match the application, `:module` to match a prefix of a module
      and `:function` to match a particular function. The level is set via `:level`. The following configuration

          level_config: [
            [application: :my_app, module: Foo.Bar, level: :debug]
            [function: "some_function/1", level: :error]
          ]

      would set the log level for any module that starts with `Foo.Bar` in application `:my_app` to :debug. In addition
      the log level for any function called `some_function` and that has arity 1 is set to `:error`. Note that if a key
      (ie., :application, :module or :function) is not present then it matches anything.

    * `logger_config:` If this key is not present then the entire configuration is passed onto the actual logger for configuration.
      In case the configuration of the logger needs to be further restricted, for example, because both `FlexLogger` and
      the logger in question are configured via a `level_config` you can use `logger_config` to provide the actual
      configuration for the logger.

  ### Logger Specific Configuration

  `Logger` specific configuration, i.e., not backend specific configuration needs to be specified at the usual place,
  for example

     config :logger,
        handle_otp_reports: true,
        handle_sasl_reports: true

  ## Supported Backends

  `FlexLogger` has been tested with :console and `LoggerFileBackend` but should also work with other logging backends.

  """

  @behaviour :gen_event

  defmodule State do
    @moduledoc false

    defstruct name: nil, logger: nil, logger_state: nil, level: :info, level_config: [], metadata_filter: []
  end

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  @doc """
  Updates configuration of flex_logger and underlying logger.
  Underlying logger may not be changed.
  """
  def handle_call({:configure, opts},  %State{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_call(_opts, %{logger: nil} = state) do
    {:ok, :no_logger, state}
  end

  def handle_call(opts, %{logger: logger, logger_state: logger_state} = state) do
    # forward to logger
    {flag, reply, updated_logger_state} =
      logger.handle_call(opts, logger_state)

    {flag, reply, %State{state| logger_state: updated_logger_state}}
  end

  def handle_event(_opts, %{logger: nil} = state) do
    # ignore, no logger set
    {:ok, state}
  end

  def handle_event({level, gl, {Logger, msg, ts, md}}, %{logger: logger, logger_state: logger_state} = state) do
    if should_log?(md, level, state.level, state.level_config) do
      {flag, updated_logger_state} =
        logger.handle_event({level, gl, {Logger, msg, ts, md}}, logger_state)

      {flag, %State{state | logger_state: updated_logger_state}}
    else
      {:ok, state}
    end
  end

  def handle_event(opts, %{logger: logger, logger_state: logger_state} = state) do
    # we forward to logger
    {flag, updated_logger_state} =
      logger.handle_event(opts, logger_state)

    {flag, %State{state | logger_state: updated_logger_state}}
  end

  def handle_info(_opts, %{logger: nil} = state), do: {:ok, state}

  def handle_info(opts, %{logger: logger, logger_state: logger_state} = state) do
    {flag, updated_logger_state} =
      logger.handle_info(opts, logger_state)

    {flag, %State{state | logger_state: updated_logger_state}}
  end

  def handle_info(_, state) do
    # ignore
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    # ignore
    {:ok, state}
  end

  def terminate(_reason, _state) do
    # ignore
    :ok
  end

  # helper

  defp should_log?(md, level, default_level, level_config) do
    case check_level_configs(md, level, level_config) do
      {:match, do_log?} -> do_log?
      :no_match -> meet_level?(level, default_level)
    end
  end

  defp meet_level?(_lvl, nil), do: true
  defp meet_level?(_lvl, :off), do: false
  defp meet_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  #    tests the metadata against the level_config configuration.
  #    returns
  #      {:match, false} - in case the config matches and the log call should not be passed on
  #      {:match, true} - in case the config matches and the log call should be passed on
  #      {:no_match} - in case no config matches
  defp check_level_configs(_md, _level, nil), do: :no_match
  defp check_level_configs(_md, _level, []), do: :no_match

  defp check_level_configs(md, level, [config | level_configs]) do
    case check_module_against_config(md, level, config) do
      :no_match ->
        check_level_configs(md, level, level_configs)
      {:match, level_matches} ->
        {:match, level_matches}
    end
  end

  defp check_module_against_config(md, level, config) do
    app = Keyword.get(md, :application, nil)
    module = Keyword.get(md, :module, nil)
    function = Keyword.get(md, :function, nil)

    allowed_app = Keyword.get(config, :application, nil)
    allowed_module = Keyword.get(config, :module, nil)
    allowed_function = Keyword.get(config, :function, nil)
    min_level = Keyword.get(config, :level, :debug)

    if (not matches?(app, allowed_app) or
        not matches_prefix?(module, allowed_module) or
        not matches?(function, allowed_function)) do
      :no_match
    else
      {:match, meet_level?(level, min_level)}
    end
  end

  defp matches?(_, nil), do: true
  defp matches?(nil, _), do: true
  defp matches?(a, b), do: a == b

  defp matches_prefix?(_, nil), do: true
  defp matches_prefix?(nil, _), do: true
  defp matches_prefix?(module, module_prefix) when is_atom(module) do
    matches_prefix?(Atom.to_string(module), module_prefix)
  end
  defp matches_prefix?(module, module_prefix) when is_atom(module_prefix) do
    matches_prefix?(module, Atom.to_string(module_prefix))
  end
  defp matches_prefix?(module, module_prefix) do
    String.starts_with?(module, module_prefix)
  end

  defp configure(name, opts), do: configure(name, opts, %State{})

  defp configure(name, opts, %State{} = state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)

    old_logger = state.logger
    logger = translate_logger(Keyword.get(opts, :logger, nil))

    logger_state = cond do
      is_nil(logger) ->
        nil
      old_logger == logger ->
        update_logger_config(logger, opts, state.logger_state)
      true ->
        {:ok, logger_state} = init_logger(logger, name)
        update_logger_config(logger, opts, logger_state)
    end

    %State{state |
      name: name,
      logger: logger,
      logger_state: logger_state,
      level: Keyword.get(opts, :default_level, :debug),
      level_config: clean_level_config(Keyword.get(opts, :level_config, [])),
    }
  end

  defp update_logger_config(logger, opts, logger_state) do
    logger_opts = Keyword.get(opts, :logger_config, opts)
    {:ok, :ok, updated_logger_state} = logger.handle_call({:configure, logger_opts}, logger_state)
    updated_logger_state
  end

  defp clean_level_config([]), do: []
  defp clean_level_config(cnf) do
    if Keyword.keyword?(cnf) do
      [cnf]
    else
      cnf
    end
  end

  defp translate_logger(:console), do: Logger.Backends.Console
  defp translate_logger(logger), do: logger

  defp init_logger(nil), do: nil
  defp init_logger(Logger.Backends.Console), do: Logger.Backends.Console.init(:console)
  defp init_logger(logger), do: logger.init(logger)

  defp init_logger(logger, name) do
    try do
      logger.init({logger, name})
    rescue
      _ -> init_logger(logger)
    end
  end

end
