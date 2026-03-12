defmodule AgentQueue.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :path, :string, null: false
      add :name, :string, null: false
      add :last_scanned, :utc_datetime
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:projects, [:path])
  end
end
