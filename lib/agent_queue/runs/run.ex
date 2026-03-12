defmodule AgentQueue.Runs.Run do
  use Ecto.Schema
  import Ecto.Changeset

  schema "runs" do
    field :command, :string
    field :stdout, :string
    field :stderr, :string
    field :exit_code, :integer
    field :duration_seconds, :integer
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :task, AgentQueue.Tasks.Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :command,
      :stdout,
      :stderr,
      :exit_code,
      :duration_seconds,
      :started_at,
      :completed_at,
      :task_id
    ])
    |> validate_required([:task_id])
    |> validate_length(:command, max: 10_000)
    |> validate_length(:stdout, max: 1_000_000)
    |> validate_length(:stderr, max: 1_000_000)
    |> foreign_key_constraint(:task_id)
  end
end
