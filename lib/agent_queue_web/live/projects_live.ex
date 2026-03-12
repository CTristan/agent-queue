defmodule AgentQueueWeb.ProjectsLive do
  @moduledoc """
  Live view for managing projects.
  """
  use AgentQueueWeb, :live_view

  alias AgentQueue.{Projects, Tasks}

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:task_stats, get_task_stats(projects))

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
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
end
