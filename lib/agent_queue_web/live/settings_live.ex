defmodule AgentQueueWeb.SettingsLive do
  @moduledoc """
  Live view for managing application settings.
  """
  use AgentQueueWeb, :live_view

  alias AgentQueue.Settings

  @impl true
  def mount(_, _, socket) do
    settings = Settings.all_settings_with_defaults()

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:form_params, %{
        "discovery_max_projects" => settings["discovery_max_projects"],
        "discovery_priority_mode" => settings["discovery_priority_mode"]
      })
      |> assign(:changeset, nil)
      |> assign(:success_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    # Validate max_projects is a positive integer
    case Integer.parse(params["discovery_max_projects"]) do
      {max_projects, ""} when max_projects > 0 ->
        # Validate priority_mode
        if params["discovery_priority_mode"] in Settings.priority_modes() do
          # Update settings
          {:ok, _} =
            Settings.update_setting("discovery_max_projects", params["discovery_max_projects"])

          {:ok, _} =
            Settings.update_setting("discovery_priority_mode", params["discovery_priority_mode"])

          socket =
            socket
            |> put_flash(:info, "Settings saved successfully")
            |> push_navigate(to: ~p"/settings")

          {:noreply, socket}
        else
          {:noreply, put_flash(socket, :error, "Invalid priority mode")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Max projects must be a positive integer")}
    end
  end

  defp priority_mode_label("alphabetical"), do: "Alphabetical (A-Z)"
  defp priority_mode_label("most_recently_modified"), do: "Most Recently Modified"
  defp priority_mode_label("least_recently_scanned"), do: "Least Recently Scanned"
  defp priority_mode_label("random"), do: "Random"
  defp priority_mode_label(_), do: "Unknown"

  defp priority_mode_description("alphabetical"), do: "Projects are sorted alphabetically by name"

  defp priority_mode_description("most_recently_modified"),
    do: "Projects discovered first are those with most recent file changes"

  defp priority_mode_description("least_recently_scanned"),
    do: "Projects discovered first are those that haven't been scanned in the longest time"

  defp priority_mode_description("random"), do: "Projects are discovered in random order"
  defp priority_mode_description(_), do: ""
end
