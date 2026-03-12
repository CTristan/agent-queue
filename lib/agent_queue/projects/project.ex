defmodule AgentQueue.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :path, :string
    field :name, :string
    field :last_scanned, :utc_datetime
    field :enabled, :boolean, default: true

    has_many :tasks, AgentQueue.Tasks.Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:path, :name, :last_scanned, :enabled])
    |> validate_required([:path, :name, :enabled])
    |> validate_length(:name, max: 255)
    |> validate_length(:path, max: 1000)
    |> unique_constraint(:path)
  end
end
