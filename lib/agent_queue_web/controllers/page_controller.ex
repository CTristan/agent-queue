defmodule AgentQueueWeb.PageController do
  @moduledoc false
  use AgentQueueWeb, :controller

  def home(conn, _) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
