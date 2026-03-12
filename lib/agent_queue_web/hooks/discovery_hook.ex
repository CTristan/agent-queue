defmodule AgentQueueWeb.DiscoveryHook do
  @moduledoc """
  LiveView on_mount hook that provides discovery status tracking across all pages.

  Subscribes to discoverer status updates via PubSub and assigns the current
  status to the socket, so the app layout can render a persistent progress bar.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  @max_log_lines 200

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:discoverer_status, AgentQueue.Discoverer.status())
      |> assign(:discovery_logs, [])
      |> assign(:discovery_logs_visible, false)

    if connected?(socket) do
      AgentQueue.Discoverer.subscribe_status()
      AgentQueue.Discoverer.subscribe_logs()
    end

    socket =
      socket
      |> attach_hook(:discovery_status, :handle_info, fn
        {:discoverer_status, status}, socket ->
          {:cont, assign(socket, :discoverer_status, status)}

        {:discoverer_log, entry}, socket ->
          logs = socket.assigns.discovery_logs ++ [entry]
          logs = Enum.take(logs, -@max_log_lines)
          {:halt, assign(socket, :discovery_logs, logs)}

        :clear_logs, socket ->
          {:halt, assign(socket, :discovery_logs, [])}

        _, socket ->
          {:cont, socket}
      end)

    socket =
      attach_hook(socket, :discovery_events, :handle_event, fn
        "toggle-discovery-logs", _, socket ->
          {:halt, assign(socket, :discovery_logs_visible, !socket.assigns.discovery_logs_visible)}

        _, _, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end
end
