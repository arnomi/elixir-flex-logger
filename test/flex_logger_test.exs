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
    config [logger: Logger.Backends.Console, level: :debug]
    debug "console logger test"
    :ok
  end

  test "works with :console logger" do
    config [logger: :console, level: :debug]
    debug "console logger test"
    :ok
  end

  test "works with named logger" do
    config [logger: LoggerMockWithName, level: :debug]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "works with unnamed logger" do
    config [logger: LoggerMockWithoutName, level: :debug]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "take default level if no specific rule matches" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [module: FooBar, level: :info]]
    reset()
    debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "take specific rule overrides default level" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [module: A, level: :info]]
    reset()
    A.debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "take module prefix" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [module: Foo, level: :info]]
    reset()
    Foo.Bar.debug "test message"
    Foo.Bar.info "info"
    assert %{:events => [info: "info"]} = mock_state()
  end

  test "test application" do
    config [logger: LoggerMockWithoutName, level: :info, level_config: [application: :flex_logger, level: :debug]]
    reset()
    A.debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "test override function" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [
                                                  [module: Foo.Bar, function: "debug/1", level: :debug],
                                                  [module: Foo, level: :info]]]
    reset()
    Foo.Bar.debug "test message"
    assert %{:events => [debug: "test message"]} = mock_state()
  end

  test "test function arity" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [
                                                            [module: Foo.Bar, function: "debug/2", level: :debug],
                                                            [module: Foo, level: :info]]]
    reset()
    assert %{:events => []} = mock_state()
  end

  test "test order matters" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [[module: Foo, level: :info],
                                                                         [module: Foo.Bar, function: "debug/1", level: :debug]]]
    reset()
    Foo.Bar.debug "test message"
    assert %{:events => []} = mock_state()
  end

  test "test multiple rules" do
    config [logger: LoggerMockWithoutName, level: :debug, level_config: [[module: Foo, level: :info], [module: A, level: :warn]]]
    reset()

    Foo.Bar.debug "test message"
    A.debug "test message"
    A.warn "warn"

    assert %{:events => [warn: "warn"]} = mock_state()
  end

  defp debug(msg) do
    Logger.debug msg
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
