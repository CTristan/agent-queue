defmodule AgentQueue.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string, null: false
      add :value, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:key])

    # Insert default settings
    flush()

    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime_str = DateTime.to_string(datetime)

    execute """
    INSERT INTO settings (key, value, inserted_at, updated_at)
    VALUES
      ('discovery_max_projects', '10', '#{datetime_str}', '#{datetime_str}'),
      ('discovery_priority_mode', 'most_recently_modified', '#{datetime_str}', '#{datetime_str}')
    """
  end
end
