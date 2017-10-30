defmodule A do
  @moduledoc false

  require Logger

  def info(msg) do
    Logger.info(msg)
  end

  def debug(msg) do
    Logger.debug(msg)
  end

  def warn(msg) do
    Logger.warn(msg)
  end

end
