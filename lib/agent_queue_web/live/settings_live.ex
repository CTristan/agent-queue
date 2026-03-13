defmodule AgentQueueWeb.SettingsLive do
  @moduledoc """
  Live view for managing application settings.
  """
  use AgentQueueWeb, :live_view

  alias AgentQueue.{Discovery, Settings}

  @impl true
  def mount(_, _, socket) do
    settings = Settings.all_settings_with_defaults()
    default_prompt = Discovery.default_discovery_prompt_template()
    prompt = effective_prompt(settings["discovery_prompt"], default_prompt)

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:default_prompt, default_prompt)
      |> assign(:form_params, %{
        "discovery_max_projects" => settings["discovery_max_projects"],
        "discovery_priority_mode" => settings["discovery_priority_mode"],
        "discovery_debug_mode" => settings["discovery_debug_mode"],
        "discovery_task_timeout" => settings["discovery_task_timeout"],
        "discovery_prompt" => prompt
      })
      |> assign(:using_default_prompt, prompt == default_prompt)
      |> assign(:changeset, nil)
      |> assign(:save_message, nil)
      |> assign(:save_message_kind, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    errors = validate_settings(params)

    if errors == [] do
      {:ok, _} =
        Settings.update_setting("discovery_max_projects", params["discovery_max_projects"])

      {:ok, _} =
        Settings.update_setting("discovery_priority_mode", params["discovery_priority_mode"])

      debug_mode = if params["discovery_debug_mode"] == "true", do: "true", else: "false"
      {:ok, _} = Settings.update_setting("discovery_debug_mode", debug_mode)

      task_timeout = params["discovery_task_timeout"] || "300"
      {:ok, _} = Settings.update_setting("discovery_task_timeout", task_timeout)

      discovery_prompt = String.trim(params["discovery_prompt"] || "")
      default_prompt = socket.assigns.default_prompt

      if discovery_prompt == "" or discovery_prompt == default_prompt do
        Settings.delete_setting("discovery_prompt")
      else
        {:ok, _} = Settings.update_setting("discovery_prompt", discovery_prompt)
      end

      effective = effective_prompt(discovery_prompt, default_prompt)
      settings = Settings.all_settings_with_defaults()

      socket =
        socket
        |> assign(:settings, settings)
        |> assign(:form_params, %{
          "discovery_max_projects" => params["discovery_max_projects"],
          "discovery_priority_mode" => params["discovery_priority_mode"],
          "discovery_debug_mode" => debug_mode,
          "discovery_task_timeout" => task_timeout,
          "discovery_prompt" => effective
        })
        |> assign(:using_default_prompt, effective == default_prompt)
        |> assign(:save_message, "Settings saved successfully")
        |> assign(:save_message_kind, :info)

      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         save_message: Enum.join(errors, ". "),
         save_message_kind: :error
       )}
    end
  end

  @impl true
  def handle_event("reset_prompt", _, socket) do
    default_prompt = socket.assigns.default_prompt
    Settings.delete_setting("discovery_prompt")

    form_params = Map.put(socket.assigns.form_params, "discovery_prompt", default_prompt)

    {:noreply,
     socket
     |> assign(:form_params, form_params)
     |> assign(:using_default_prompt, true)
     |> assign(:save_message, "Prompt reset to default")
     |> assign(:save_message_kind, :info)}
  end

  defp effective_prompt(prompt, default) do
    trimmed = String.trim(prompt || "")
    if trimmed == "", do: default, else: trimmed
  end

  defp validate_settings(params) do
    errors = []

    errors =
      case Integer.parse(params["discovery_max_projects"]) do
        {n, ""} when n > 0 -> errors
        _ -> errors ++ ["Max projects must be a positive integer"]
      end

    errors =
      case Integer.parse(params["discovery_task_timeout"] || "300") do
        {n, ""} when n > 0 -> errors
        _ -> errors ++ ["Task timeout must be a positive integer"]
      end

    errors =
      if params["discovery_priority_mode"] in Settings.priority_modes() do
        errors
      else
        errors ++ ["Invalid priority mode"]
      end

    errors
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
