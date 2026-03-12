defmodule AgentQueue.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "proposed"
    field :priority, :integer, default: 10
    field :source, :string, default: "auto"
    field :created_at, :utc_datetime
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :project, AgentQueue.Projects.Project
    has_many :runs, AgentQueue.Runs.Run

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :title,
      :description,
      :status,
      :priority,
      :source,
      :created_at,
      :started_at,
      :completed_at,
      :project_id
    ])
    |> validate_required([:project_id, :title, :status])
    |> validate_length(:title, max: 500)
    |> validate_length(:description, max: 100_000)
    |> validate_inclusion(:status, ~w(proposed approved running review completed failed rejected))
    |> validate_inclusion(:source, ~w(auto manual))
    |> foreign_key_constraint(:project_id)
  end
end
