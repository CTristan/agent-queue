defmodule AgentQueue.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :command, :string
      add :stdout, :string
      add :stderr, :string
      add :exit_code, :integer
      add :duration_seconds, :integer
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:runs, [:task_id])
  end
end
