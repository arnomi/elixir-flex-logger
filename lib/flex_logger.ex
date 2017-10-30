defmodule FlexLogger do
  @moduledoc false

  @behaviour :gen_event

  defmodule State do
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
    IO.puts "foobar"
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

  defp should_log?(md, level, log_level, level_config) do
    case check_level_configs(md, level, level_config) do
      {:match, do_log?} -> do_log?
      :no_match -> meet_level?(log_level, level)
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

  defp matches_prefix?(_, nil), do: false
  defp matches_prefix?(nil, _), do: false
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
        {:ok, :ok, updated_logger_state} = logger.handle_call({:configure, opts}, state.logger_state)
        updated_logger_state
      true ->
        {:ok, logger_state} = init_logger(logger, name)
        logger_state
    end

    %State{state |
      name: name,
      logger: logger,
      logger_state: logger_state,
      level: Keyword.get(opts, :level, :debug),
      level_config: clean_level_config(Keyword.get(opts, :level_config, [])),
    }
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
