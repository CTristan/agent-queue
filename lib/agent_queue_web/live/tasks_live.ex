defmodule AgentQueueWeb.TasksLive do
  use AgentQueueWeb, :live_view

  alias AgentQueue.{Runner, Tasks}

  @impl true
  def mount(_params, _session, socket) do
    Tasks.list_tasks(order_by: {:asc, :priority})

    socket =
      socket
      |> assign(:tasks, Tasks.list_tasks(order_by: {:asc, :priority}))
      |> assign(:filter_status, "all")
      |> assign(:filter_project_id, nil)
      |> assign(:runner_status, %{running: false, current_task: nil, budget_remaining_seconds: 0})
      |> assign(:show_task_details, nil)
      |> assign(:task_budget_minutes, 60)

    # Subscribe to runner status updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AgentQueue.PubSub, "runner:status")
      Phoenix.PubSub.subscribe(AgentQueue.PubSub, "tasks:update")
    end

    {:ok, socket}
  end

  @valid_statuses ~w(all proposed approved running review completed failed rejected)

  @impl true
  def handle_params(params, _uri, socket) do
    filter_status = Map.get(params, "status", "all")
    filter_status = if filter_status in @valid_statuses, do: filter_status, else: "all"
    filter_project_id = Map.get(params, "project_id")

    socket =
      socket
      |> assign(:filter_status, filter_status)
      |> assign(:filter_project_id, filter_project_id)
      |> assign(:tasks, list_tasks(filter_status, filter_project_id))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:runner_status, status}, socket) do
    {:noreply, assign(socket, :runner_status, status)}
  end

  @impl true
  def handle_info({:tasks_updated, _}, socket) do
    {:noreply,
     assign(
       socket,
       :tasks,
       list_tasks(socket.assigns.filter_status, socket.assigns.filter_project_id)
     )}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/tasks?status=#{status}",
       replace: true
     )}
  end

  @impl true
  def handle_event("approve_task", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        task = Tasks.get_task!(id)

        case Tasks.approve_task(task) do
          {:ok, _task} ->
            broadcast_tasks_update()

            {:noreply,
             assign(
               socket,
               :tasks,
               list_tasks(socket.assigns.filter_status, socket.assigns.filter_project_id)
             )}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to approve task")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid task ID")}
    end
  end

  @impl true
  def handle_event("reject_task", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        task = Tasks.get_task!(id)

        case Tasks.reject_task(task) do
          {:ok, _task} ->
            broadcast_tasks_update()

            {:noreply,
             assign(
               socket,
               :tasks,
               list_tasks(socket.assigns.filter_status, socket.assigns.filter_project_id)
             )}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to reject task")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid task ID")}
    end
  end

  @impl true
  def handle_event("complete_task", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        task = Tasks.get_task!(id)

        case Tasks.complete_task(task) do
          {:ok, _task} ->
            broadcast_tasks_update()

            {:noreply,
             assign(
               socket,
               :tasks,
               list_tasks(socket.assigns.filter_status, socket.assigns.filter_project_id)
             )}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to complete task")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid task ID")}
    end
  end

  @impl true
  def handle_event("toggle_task_details", %{"id" => id_string}, socket) do
    case Integer.parse(id_string) do
      {id, ""} ->
        Tasks.get_task_with_runs!(id)

        new_show =
          if socket.assigns.show_task_details == id_string, do: nil, else: id_string

        {:noreply, assign(socket, :show_task_details, new_show)}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid task ID")}
    end
  end

  @impl true
  def handle_event("start_run", _params, socket) do
    Runner.start_run(budget_minutes: socket.assigns.task_budget_minutes)
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_run", _params, socket) do
    Runner.stop_run()
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_budget", %{"budget" => budget}, socket) do
    case Integer.parse(budget) do
      {minutes, ""} ->
        {:noreply, assign(socket, :task_budget_minutes, minutes)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_priority", %{"id" => id_string, "priority" => priority}, socket) do
    with {id, ""} <- Integer.parse(id_string),
         {p, ""} <- Integer.parse(priority) do
      task = Tasks.get_task!(id)
      Tasks.update_task_priority(task, p)
      broadcast_tasks_update()

      {:noreply,
       assign(
         socket,
         :tasks,
         list_tasks(socket.assigns.filter_status, socket.assigns.filter_project_id)
       )}
    else
      _ -> {:noreply, put_flash(socket, :error, "Invalid task ID or priority")}
    end
  end

  defp list_tasks("all", nil) do
    Tasks.list_tasks(order_by: {:asc, :priority})
  end

  defp list_tasks("all", project_id) do
    Tasks.list_tasks(status: "all", project_id: project_id, order_by: {:asc, :priority})
  end

  defp list_tasks(status, nil) do
    Tasks.list_tasks(status: status, order_by: {:asc, :priority})
  end

  defp list_tasks(status, project_id) do
    Tasks.list_tasks(status: status, project_id: project_id, order_by: {:asc, :priority})
  end

  defp broadcast_tasks_update do
    Phoenix.PubSub.broadcast(AgentQueue.PubSub, "tasks:update", {:tasks_updated, :now})
  end

  defp format_datetime(nil), do: "Never"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp status_badge("proposed"), do: "badge-neutral"
  defp status_badge("approved"), do: "badge-info"
  defp status_badge("running"), do: "badge-accent"
  defp status_badge("review"), do: "badge-warning"
  defp status_badge("completed"), do: "badge-success"
  defp status_badge("failed"), do: "badge-error"
  defp status_badge("rejected"), do: "badge-ghost"
  defp status_badge(_), do: "badge-ghost"

  defp status_icon("proposed"), do: "⏳"
  defp status_icon("approved"), do: "✅"
  defp status_icon("running"), do: "🔄"
  defp status_icon("review"), do: "👀"
  defp status_icon("completed"), do: "✓"
  defp status_icon("failed"), do: "✗"
  defp status_icon("rejected"), do: "🚫"
  defp status_icon(_), do: "?"

  defp format_duration(seconds) when is_integer(seconds) and seconds > 0 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  defp format_duration(_), do: "N/A"
end
