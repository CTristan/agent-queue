defmodule AgentQueue.Repo.Migrations.AddFieldLengthLimits do
  use Ecto.Migration

  def up do
    # Tasks table - add size constraints
    alter table(:tasks) do
      modify :title, :string, size: 500, null: false
      modify :description, :text
    end

    # Runs table - add size constraints
    alter table(:runs) do
      modify :command, :string, size: 10_000
      modify :stdout, :text
      modify :stderr, :text
    end

    # Projects table - add size constraints
    alter table(:projects) do
      modify :name, :string, size: 255, null: false
      modify :path, :string, size: 1000, null: false
    end
  end

  def down do
    # Tasks table - remove size constraints
    alter table(:tasks) do
      modify :title, :string, null: false
      modify :description, :string
    end

    # Runs table - remove size constraints
    alter table(:runs) do
      modify :command, :string
      modify :stdout, :string
      modify :stderr, :string
    end

    # Projects table - remove size constraints
    alter table(:projects) do
      modify :name, :string, null: false
      modify :path, :string, null: false
    end
  end
end
