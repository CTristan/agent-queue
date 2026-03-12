defmodule AgentQueueWeb.ProjectsLive do
  @moduledoc """
  Live view for managing projects.
  """
  use AgentQueueWeb, :live_view

  alias AgentQueue.{Projects, Tasks}
  import AgentQueueWeb.FormatHelpers

  @impl true
  def mount(_, _, socket) do
    projects = Projects.list_projects()
    max_projects = AgentQueue.Settings.get_discovery_max_projects()
    priority_mode = AgentQueue.Settings.get_discovery_priority_mode()

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:task_stats, get_task_stats(projects))
      |> assign(:max_projects, max_projects)
      |> assign(:priority_mode, priority_mode)

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:discoverer_status, _status}, socket) do
    # Refresh project list when discovery status changes (hook handles the status assign)
    new_projects = Projects.list_projects()
    new_task_stats = get_task_stats(new_projects)

    socket =
      socket
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
          {:ok, _} ->
            projects = Projects.list_projects()

            socket =
              socket
              |> assign(:projects, projects)
              |> assign(:task_stats, get_task_stats(projects))

            {:noreply, socket}

          {:error, _} ->
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

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete project")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid project ID")}
    end
  end

  @impl true
  def handle_event("start_discovery", _, socket) do
    AgentQueue.Discoverer.start_discovery()
    {:noreply, socket}
  end

  defp get_task_stats(projects) do
    Enum.map(projects, fn project ->
      {project.id, Tasks.get_task_stats(project)}
    end)
    |> Map.new()
  end

  defp get_stat(stats, key, default \\ 0) do
    Map.get(stats, key, default)
  end
end
