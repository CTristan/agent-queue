defmodule AgentQueue.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias AgentQueue.Projects.Project
  alias AgentQueue.Repo

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]
  """
  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Returns the list of enabled projects.

  ## Examples

      iex> list_enabled_projects()
      [%Project{}, ...]
  """
  def list_enabled_projects do
    from(p in Project, where: p.enabled == true)
    |> Repo.all()
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Gets a project by path.

  ## Examples

      iex> get_project_by_path("/path/to/project")
      %Project{}

      iex> get_project_by_path("/nonexistent")
      nil
  """
  def get_project_by_path(path) do
    Repo.get_by(Project, path: path)
  end

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  @doc """
  Returns projects that haven't been scanned in the last `hours` hours.

  ## Examples

      iex> list_projects_needing_scan(24)
      [%Project{}, ...]
  """
  def list_projects_needing_scan(hours \\ 24) do
    cutoff = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    from(p in Project,
      where: p.enabled == true and (is_nil(p.last_scanned) or p.last_scanned < ^cutoff)
    )
    |> Repo.all()
  end

  @doc """
  Updates the last_scanned timestamp for a project.

  ## Examples

      iex> update_last_scanned(project)
      {:ok, %Project{}}
  """
  def update_last_scanned(%Project{} = project) do
    update_project(project, %{last_scanned: DateTime.utc_now()})
  end

  @doc """
  Gets or creates a project by path.

  ## Examples

      iex> get_or_create_project("/path/to/project")
      {:ok, %Project{}}
  """
  def get_or_create_project(path, attrs \\ %{}) do
    case get_project_by_path(path) do
      nil ->
        default_attrs = %{
          path: path,
          name: Path.basename(path),
          enabled: true
        }

        create_project(Map.merge(default_attrs, attrs))

      project ->
        {:ok, project}
    end
  end
end
