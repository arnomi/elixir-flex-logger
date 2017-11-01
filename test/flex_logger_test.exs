defmodule FlexLoggerTest do
  use ExUnit.Case, async: false
  doctest FlexLogger

  require Logger

  @backend {FlexLogger, :test}
  Logger.add_backend @backend

  test "does not crash on empty logger" do
    config logger: nil
    debug "empty logger test"
    :ok
  end

  test "works with console logger with full name" do
    config [logger: Logger.Backends.Console, default_level: :debug]
    debug "console logger test"
    :ok
  end

  test "works with :console logger" do
    config [logger: :console, default_level: :debug]
    debug "console logger test"
    :ok
  end

  test "works with named logger" do
    config [logger: LoggerMockWithName, default_level: :debug]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "default_level filters" do
    config [logger: LoggerMockWithName, default_level: :warn]
    reset()
    debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "default_level includes" do
    config [logger: LoggerMockWithName, default_level: :warn]
    reset()
    warn "test message"
    assert %{:events => [warn: "test message"]} = mock_state()
  end

  test "works with unnamed logger" do
    config [logger: LoggerMockWithoutName, default_level: :debug]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "take default level if no specific rule matches" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [module: FooBar, level: :info]]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "turn off logging via :off" do
    config [logger: LoggerMockWithoutName, default_level: :off]
    reset()
    debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "override :off" do
    config [logger: LoggerMockWithoutName, default_level: :off, level_config: [module: A, level: :info]]
    reset()
    A.info "test message"
    assert %{:events => [info: "test message"]} = mock_state()
  end

  test "take specific rule overrides default level" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [module: A, level: :info]]
    reset()
    A.debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "take module prefix" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [module: Foo, level: :info]]
    reset()
    Foo.Bar.debug "test message"
    Foo.Bar.info "info"
    assert %{:events => [info: "info"]} = mock_state()
  end

  test "test application" do
    config [logger: LoggerMockWithoutName, default_level: :info, level_config: [application: :flex_logger, level: :debug]]
    reset()
    A.debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "test override function" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [
                                                  [module: Foo.Bar, function: "debug/1", level: :debug],
                                                  [module: Foo, level: :info]]]
    reset()
    Foo.Bar.debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "test function arity" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [
                                                            [module: Foo.Bar, function: "debug/2", level: :debug],
                                                            [module: Foo, level: :info]]]
    reset()
    assert %{:events => []} = mock_state()
  end

  test "test order matters" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [[module: Foo, level: :info],
                                                                         [module: Foo.Bar, function: "debug/1", level: :debug]]]
    reset()
    Foo.Bar.debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "multiple rules" do
    config [logger: LoggerMockWithoutName, default_level: :debug, level_config: [[module: Foo, level: :info], [module: A, level: :warn]]]
    reset()

    Foo.Bar.debug "test message"
    A.debug "test message"
    A.warn "warn"

    assert %{:events => [warn: "warn"]} = mock_state()
  end

  test "message contains" do
    config [logger: LoggerMockWithoutName, default_level: :error, level_config: [[message: "foo", level: :debug]]]
    reset()

    A.warn "foo warn"
    A.warn "bar warn"

    assert %{:events => [warn: "foo warn"]} = mock_state()
  end

  test "message regex" do
    config [logger: LoggerMockWithoutName, default_level: :error, level_config: [[message: ~r/bar/, level: :debug]]]
    reset()

    A.warn "foo warn"
    A.warn "bar warn"

    assert %{:events => [warn: "bar warn"]} = mock_state()
  end

  test "message function" do
    config [logger: LoggerMockWithoutName, default_level: :error, level_config: [[message: fn msg -> String.contains?(msg, "bar") end, level: :debug]]]
    reset()

    A.warn "foo warn"
    A.warn "bar warn"

    assert %{:events => [warn: "bar warn"]} = mock_state()
  end

  test "can set config directly" do
    config [logger: LoggerMockWithoutName]
    reset()
    config [logger: LoggerMockWithoutName, default_level: :debug, foo: :bar]

    assert %{:configure => [logger: LoggerMockWithoutName, default_level: :debug, foo: :bar]} = mock_state()
  end

  defp debug(msg) do
    Logger.debug msg
    Logger.flush()
  end

  defp warn(msg) do
    Logger.warn msg
    Logger.flush()
  end

  defp mock_state do
    :gen_event.call(Logger, @backend, :get_state)
  end

  defp reset do
    :gen_event.call(Logger, @backend, :reset)
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
