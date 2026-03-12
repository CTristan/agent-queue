defmodule AgentQueue.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias AgentQueue.Projects.Project
  alias AgentQueue.Repo
  alias AgentQueue.Tasks.Task

  @doc """
  Returns the list of tasks.

  ## Examples

      iex> list_tasks()
      [%Task{}, ...]
  """
  def list_tasks(opts \\ []) do
    query = from(t in Task, as: :task)

    query =
      if status = Keyword.get(opts, :status) do
        where(query, [t], t.status == ^status)
      else
        query
      end

    query =
      if project_id = Keyword.get(opts, :project_id) do
        where(query, [t], t.project_id == ^project_id)
      else
        query
      end

    query =
      case Keyword.get(opts, :order_by, {:asc, :priority}) do
        {:asc, :priority} -> order_by(query, asc: :priority)
        {:desc, :priority} -> order_by(query, desc: :priority)
        {:asc, :id} -> order_by(query, asc: :id)
        {:desc, :id} -> order_by(query, desc: :id)
        {:asc, field} -> order_by(query, asc: ^field)
        {:desc, field} -> order_by(query, desc: ^field)
      end

    query
    |> preload([:project])
    |> Repo.all()
  end

  @doc """
  Returns approved tasks sorted by priority.

  ## Examples

      iex> list_approved_tasks()
      [%Task{}, ...]
  """
  def list_approved_tasks do
    from(t in Task,
      where: t.status == "approved",
      order_by: [asc: t.priority, asc: t.id],
      preload: [:project]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.

  ## Examples

      iex> get_task!(123)
      %Task{}

      iex> get_task!(456)
      ** (Ecto.NoResultsError)

  """
  def get_task!(id) do
    Repo.get!(Task, id)
    |> Repo.preload([:project, :runs])
  end

  @doc """
  Gets a task with its runs preloaded.

  ## Examples

      iex> get_task_with_runs!(123)
      %Task{runs: [...]}
  """
  def get_task_with_runs!(id) do
    Repo.get!(Task, id)
    |> Repo.preload([
      :project,
      runs: from(r in AgentQueue.Runs.Run, order_by: [desc: r.inserted_at])
    ])
  end

  @doc """
  Creates a task.

  ## Examples

      iex> create_task(%{field: value})
      {:ok, %Task{}}

      iex> create_task(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a task for a project.

  ## Examples

      iex> create_task_for_project(project, %{title: "Test"})
      {:ok, %Task{}}
  """
  def create_task_for_project(%Project{id: project_id}, attrs) do
    default_attrs = %{
      project_id: project_id,
      status: "proposed",
      priority: 10,
      source: "auto",
      created_at: DateTime.utc_now()
    }

    create_task(Map.merge(default_attrs, attrs))
  end

  @doc """
  Updates a task.

  ## Examples

      iex> update_task(task, %{field: new_value})
      {:ok, %Task{}}

      iex> update_task(task, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task.

  ## Examples

      iex> delete_task(task)
      {:ok, %Task{}}

      iex> delete_task(task)
      {:error, %Ecto.Changeset{}}

  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.

  ## Examples

      iex> change_task(task)
      %Ecto.Changeset{data: %Task{}}

  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Approves a task.

  ## Examples

      iex> approve_task(task)
      {:ok, %Task{}}
  """
  def approve_task(%Task{} = task) do
    update_task(task, %{status: "approved"})
  end

  @doc """
  Rejects a task.

  ## Examples

      iex> reject_task(task)
      {:ok, %Task{}}
  """
  def reject_task(%Task{} = task) do
    update_task(task, %{status: "rejected"})
  end

  @doc """
  Marks a task as running.

  ## Examples

      iex> start_task(task)
      {:ok, %Task{}}
  """
  def start_task(%Task{} = task) do
    update_task(task, %{status: "running", started_at: DateTime.utc_now()})
  end

  @doc """
  Marks a task as completed.

  ## Examples

      iex> complete_task(task)
      {:ok, %Task{}}
  """
  def complete_task(%Task{} = task) do
    update_task(task, %{status: "completed", completed_at: DateTime.utc_now()})
  end

  @doc """
  Marks a task as failed.

  ## Examples

      iex> fail_task(task)
      {:ok, %Task{}}
  """
  def fail_task(%Task{} = task) do
    update_task(task, %{status: "failed", completed_at: DateTime.utc_now()})
  end

  @doc """
  Marks a task as review (for human verification).

  ## Examples

      iex> mark_for_review(task)
      {:ok, %Task{}}
  """
  def mark_for_review(%Task{} = task) do
    update_task(task, %{status: "review", completed_at: DateTime.utc_now()})
  end

  @doc """
  Returns tasks count grouped by status for a project.

  ## Examples

      iex> get_task_stats(project)
      %{proposed: 5, approved: 2, ...}
  """
  def get_task_stats(%Project{id: project_id}) do
    from(t in Task,
      where: t.project_id == ^project_id,
      select: {t.status, count(t.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Checks if a project has pending tasks (proposed or approved).

  ## Examples

      iex> project_has_pending_tasks?(project)
      true
  """
  def project_has_pending_tasks?(%Project{id: project_id}) do
    query =
      from(t in Task, where: t.project_id == ^project_id and t.status in ["proposed", "approved"])

    Repo.aggregate(query, :count) > 0
  end

  @doc """
  Updates task priority.

  ## Examples

      iex> update_task_priority(task, 5)
      {:ok, %Task{}}
  """
  def update_task_priority(%Task{} = task, priority)
      when is_integer(priority) and priority >= 0 do
    update_task(task, %{priority: priority})
  end

  @doc """
  Reorders tasks by priority.

  ## Examples

      iex> reorder_tasks([task1, task2])
      :ok
  """
  def reorder_tasks(tasks) when is_list(tasks) do
    Enum.each(tasks, fn {task, priority} ->
      update_task_priority(task, priority)
    end)

    :ok
  end
end
