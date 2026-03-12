defmodule AgentQueueWeb.DiscoveryHook do
  @moduledoc """
  LiveView on_mount hook that provides discovery status tracking across all pages.

  Subscribes to discoverer status updates via PubSub and assigns the current
  status to the socket, so the app layout can render a persistent progress bar.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket = assign(socket, :discoverer_status, AgentQueue.Discoverer.status())

    if connected?(socket) do
      AgentQueue.Discoverer.subscribe_status()
    end

    socket =
      attach_hook(socket, :discovery_status, :handle_info, fn
        {:discoverer_status, status}, socket ->
          {:cont, assign(socket, :discoverer_status, status)}

        _, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end
end
