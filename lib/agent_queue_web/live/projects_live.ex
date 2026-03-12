defmodule AgentQueueWeb.ProjectsLive do
  @moduledoc """
  Live view for managing projects.
  """
  use AgentQueueWeb, :live_view

  alias AgentQueue.{Projects, Tasks}

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()
    max_projects = AgentQueue.Settings.get_discovery_max_projects()
    priority_mode = AgentQueue.Settings.get_discovery_priority_mode()

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:task_stats, get_task_stats(projects))
      |> assign(:max_projects, max_projects)
      |> assign(:priority_mode, priority_mode)
      |> assign(:discoverer_status, %{
        discovering: false,
        stage: nil,
        discovered_projects: 0,
        discovered_tasks: 0,
        elapsed_seconds: 0
      })

    # Subscribe to discoverer status updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AgentQueue.PubSub, "discoverer:status")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:discoverer_status, status}, socket) do
    new_projects = Projects.list_projects()
    new_task_stats = get_task_stats(new_projects)

    socket =
      socket
      |> assign(:discoverer_status, status)
      |> assign(:projects, new_projects)
      |> assign(:task_stats, new_task_stats)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_enabled", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        project = Projects.get_project!(id)

        case Projects.update_project(project, %{enabled: not project.enabled}) do
          {:ok, _updated_project} ->
            projects = Projects.list_projects()

            socket =
              socket
              |> assign(:projects, projects)
              |> assign(:task_stats, get_task_stats(projects))

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update project")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid project ID")}
    end
  end

  @impl true
  def handle_event("delete_project", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        project = Projects.get_project!(id)

        case Projects.delete_project(project) do
          {:ok, _} ->
            projects = Projects.list_projects()

            socket =
              socket
              |> assign(:projects, projects)
              |> assign(:task_stats, get_task_stats(projects))
              |> put_flash(:info, "Project deleted")

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete project")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid project ID")}
    end
  end

  @impl true
  def handle_event("start_discovery", _params, socket) do
    AgentQueue.Discoverer.start_discovery()
    {:noreply, socket}
  end

  defp get_task_stats(projects) do
    Enum.map(projects, fn project ->
      {project.id, Tasks.get_task_stats(project)}
    end)
    |> Map.new()
  end

  defp format_datetime(nil), do: "Never"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp get_stat(stats, key, default \\ 0) do
    Map.get(stats, key, default)
  end

  defp format_duration(seconds) when is_integer(seconds) and seconds > 0 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  defp format_duration(_), do: "0s"
end
