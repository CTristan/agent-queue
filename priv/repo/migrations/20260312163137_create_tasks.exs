defmodule AgentQueue.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :string
      add :status, :string, default: "proposed", null: false
      add :priority, :integer, default: 10, null: false
      add :source, :string, default: "auto", null: false
      add :created_at, :utc_datetime, null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:project_id])
    create index(:tasks, [:status])
    create index(:tasks, [:priority])
  end
end
