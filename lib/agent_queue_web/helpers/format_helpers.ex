defmodule AgentQueueWeb.FormatHelpers do
  @moduledoc """
  Shared formatting helpers for LiveViews.
  """

  def format_datetime(nil), do: "Never"
  def format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  def format_duration(seconds) when is_integer(seconds) and seconds > 0 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  def format_duration(_), do: "0s"
end
