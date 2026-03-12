defmodule AgentQueue.Runs do
  @moduledoc """
  The Runs context.
  """

  import Ecto.Query, warn: false
  alias AgentQueue.Repo
  alias AgentQueue.Runs.Run

  @doc """
  Returns the list of runs for a task.

  ## Examples

      iex> list_runs_for_task(task_id)
      [%Run{}, ...]
  """
  def list_runs_for_task(task_id) do
    from(r in Run, where: r.task_id == ^task_id, order_by: [desc: r.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single run.

  Raises `Ecto.NoResultsError` if the Run does not exist.

  ## Examples

      iex> get_run!(123)
      %Run{}

      iex> get_run!(456)
      ** (Ecto.NoResultsError)

  """
  def get_run!(id), do: Repo.get!(Run, id)

  @doc """
  Creates a run.

  ## Examples

      iex> create_run(%{field: value})
      {:ok, %Run{}}

      iex> create_run(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a run for a task.

  ## Examples

      iex> create_run_for_task(task, %{command: "pi -p test"})
      {:ok, %Run{}}
  """
  def create_run_for_task(%AgentQueue.Tasks.Task{id: task_id}, attrs) do
    default_attrs = %{
      task_id: task_id
    }

    create_run(Map.merge(default_attrs, attrs))
  end

  @doc """
  Updates a run.

  ## Examples

      iex> update_run(run, %{field: new_value})
      {:ok, %Run{}}

      iex> update_run(run, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a run.

  ## Examples

      iex> delete_run(run)
      {:ok, %Run{}}

      iex> delete_run(run)
      {:error, %Ecto.Changeset{}}

  """
  def delete_run(%Run{} = run) do
    Repo.delete(run)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking run changes.

  ## Examples

      iex> change_run(run)
      %Ecto.Changeset{data: %Run{}}

  """
  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  @doc """
  Starts a new run for a task.

  ## Examples

      iex> start_run(task, "pi -p test")
      {:ok, %Run{}}
  """
  def start_run(%AgentQueue.Tasks.Task{id: task_id}, command) do
    attrs = %{
      task_id: task_id,
      command: command,
      started_at: DateTime.utc_now()
    }

    create_run(attrs)
  end

  @doc """
  Completes a run with results.

  ## Examples

      iex> complete_run(run, %{exit_code: 0, stdout: "output", stderr: ""})
      {:ok, %Run{}}
  """
  def complete_run(%Run{} = run, attrs) do
    completed_at = DateTime.utc_now()
    duration = DateTime.diff(completed_at, run.started_at)

    default_attrs = %{
      completed_at: completed_at,
      duration_seconds: duration
    }

    update_run(run, Map.merge(default_attrs, attrs))
  end

  @doc """
  Returns total runtime for a task.

  ## Examples

      iex> get_total_runtime(task_id)
      3600
  """
  def get_total_runtime(task_id) do
    from(r in Run,
      where: r.task_id == ^task_id and not is_nil(r.duration_seconds),
      select: sum(r.duration_seconds)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end
end
