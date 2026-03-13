defmodule AgentQueue.Settings do
  @moduledoc """
  Context for managing application settings.
  """

  import Ecto.Query, warn: false
  require Logger
  alias AgentQueue.Repo
  alias AgentQueue.Settings.Setting

  # Default values for settings
  @defaults %{
    "discovery_max_projects" => "10",
    "discovery_priority_mode" => "most_recently_modified",
    "discovery_debug_mode" => "false",
    "discovery_task_timeout" => "300",
    "discovery_prompt" => ""
  }

  @priority_modes [
    "alphabetical",
    "most_recently_modified",
    "least_recently_scanned",
    "random"
  ]

  @doc """
  Gets the value for a setting key, or the default value if not set.
  """
  def get(key, default \\ nil) do
    case Repo.get_by(Setting, key: key) do
      nil -> default || @defaults[key]
      setting -> setting.value
    end
  end

  @doc """
  Gets an integer setting value, or the default if not set or invalid.
  """
  def get_int(key, default \\ nil) do
    case get(key) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> default
        end
    end
  end

  @doc """
  Updates a setting value.
  """
  def update_setting(key, value) do
    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{key: key, value: value}
        |> Setting.changeset(%{key: key, value: value})
        |> Repo.insert()

      setting ->
        setting
        |> Setting.changeset(%{value: value})
        |> Repo.update()
    end
  end

  @doc """
  Deletes a setting by key, reverting it to its default value.
  """
  def delete_setting(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> :ok
      setting -> Repo.delete(setting) && :ok
    end
  end

  @doc """
  Gets all settings as a map.
  """
  def all_settings do
    from(s in Setting)
    |> Repo.all()
    |> Enum.map(fn setting -> {setting.key, setting.value} end)
    |> Map.new()
  end

  @doc """
  Gets all settings with their defaults as a map.
  """
  def all_settings_with_defaults do
    Map.merge(@defaults, all_settings())
  end

  @doc """
  Gets the maximum number of projects to discover.
  """
  def get_discovery_max_projects do
    get_int("discovery_max_projects", 10)
  end

  @doc """
  Gets the discovery priority mode.
  """
  def get_discovery_priority_mode do
    mode = get("discovery_priority_mode", "most_recently_modified")
    if mode in @priority_modes, do: mode, else: "most_recently_modified"
  end

  @doc """
  Gets the discovery debug mode setting.
  """
  def get_discovery_debug_mode do
    get("discovery_debug_mode", "false") == "true"
  end

  @doc """
  Gets the per-project discovery task timeout in seconds.
  """
  def get_discovery_task_timeout do
    get_int("discovery_task_timeout", 300)
  end

  @doc """
  Gets the custom discovery prompt, or nil if using the default.
  """
  def get_discovery_prompt do
    case get("discovery_prompt", "") do
      "" -> nil
      prompt -> prompt
    end
  end

  @doc """
  Returns the list of available priority modes.
  """
  def priority_modes do
    @priority_modes
  end

  @doc """
  Ensures all default settings exist in the database.
  """
  def ensure_defaults do
    Enum.each(@defaults, fn {key, value} ->
      # Skip empty defaults — they represent "no value set" and would fail validation
      if value == "" do
        :ok
      else
        case Repo.get_by(Setting, key: key) do
          nil ->
            %Setting{key: key, value: value}
            |> Setting.changeset(%{key: key, value: value})
            |> Repo.insert()
            |> case do
              {:ok, _} ->
                :ok

              {:error, changeset} ->
                Logger.error(
                  "Failed to insert default setting #{key}: #{inspect(changeset.errors)}"
                )
            end

          _ ->
            :ok
        end
      end
    end)
  end
end
