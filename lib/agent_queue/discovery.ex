defmodule AgentQueue.Discovery do
  @moduledoc """
  Task discovery module that scans projects and proposes tasks.
  """

  require Logger
  alias AgentQueue.{Projects, Settings, Tasks}

  @doc """
  Scan all projects in the configured projects directory.

  ## Examples

      iex> AgentQueue.Discovery.scan_projects()
      {:ok, discovered_count}
  """
  def scan_projects(opts \\ []) do
    projects_dir = get_projects_dir()
    skip_patterns = get_skip_patterns()

    # Get max_projects from settings or opts
    max_projects =
      case Keyword.get(opts, :max_projects) do
        nil -> AgentQueue.Settings.get_discovery_max_projects()
        :unlimited -> :unlimited
        val -> val
      end

    Logger.info("Scanning projects directory: #{projects_dir}")
    broadcast_log(:info, "Scanning projects directory: #{projects_dir}")

    discovered =
      projects_dir
      |> list_git_projects(skip_patterns, max_projects)
      |> Enum.map(&register_project/1)
      |> Enum.count(fn {status, _} -> status == :created end)

    {:ok, discovered}
  end

  @doc """
  Discover tasks for a specific project.

  ## Examples

      iex> AgentQueue.Discovery.discover_tasks(project)
      {:ok, discovered_count}
  """
  def discover_tasks(project, opts \\ []) do
    Logger.info("Discovering tasks for project: #{project.name}")
    broadcast_log(:info, "Discovering tasks for project: #{project.name}")

    # Check if project has pending tasks
    if Tasks.project_has_pending_tasks?(project) do
      Logger.info("Project has pending tasks, skipping discovery")
      broadcast_log(:info, "Project #{project.name} has pending tasks, skipping")
      {:ok, 0}
    else
      discovered = discover_and_create_tasks(project, opts)
      {:ok, discovered}
    end
  end

  @doc """
  Discover tasks for all projects.

  ## Examples

      iex> AgentQueue.Discovery.discover_all_tasks()
      {:ok, total_discovered}
  """
  def discover_all_tasks(opts \\ []) do
    max_time_seconds = Keyword.get(opts, :max_time_seconds, 30 * 60)
    start_time = System.monotonic_time(:second)

    Logger.info("Discovering tasks for all projects (max time: #{max_time_seconds}s)")
    broadcast_log(:info, "Discovering tasks for all projects (max time: #{max_time_seconds}s)")

    total_discovered =
      Projects.list_enabled_projects()
      |> Enum.take_while(fn _ ->
        elapsed = System.monotonic_time(:second) - start_time
        elapsed < max_time_seconds
      end)
      |> Enum.map(fn project ->
        {:ok, count} = discover_tasks(project, opts)
        count
      end)
      |> Enum.sum()

    {:ok, total_discovered}
  end

  defp broadcast_log(level, message) do
    AgentQueue.Discoverer.broadcast_log(level, message)
  end

  # Private Functions

  defp get_projects_dir do
    path = Application.get_env(:agent_queue, :projects_dir, System.user_home!() <> "/projects")

    # Expand and normalize path
    expanded_path = Path.expand(path)

    # Validate path exists and is accessible
    unless File.dir?(expanded_path) do
      raise ArgumentError, "Projects directory does not exist: #{expanded_path}"
    end

    expanded_path
  end

  defp get_skip_patterns do
    Application.get_env(:agent_queue, :discovery_skip_patterns, [
      "node_modules",
      ".git",
      "target",
      "_build",
      "deps",
      ".elixir_ls",
      "vendor"
    ])
  end

  defp list_git_projects(dir, skip_patterns, max_projects) do
    case File.ls(dir) do
      {:ok, entries} ->
        projects =
          entries
          |> Enum.filter(fn name ->
            path = Path.join(dir, name)

            is_dir = File.dir?(path)
            is_skipped = Enum.any?(skip_patterns, &String.starts_with?(name, &1))
            is_git = is_dir and not is_skipped and git_project?(path)

            if is_dir and not is_skipped and not is_git do
              broadcast_log(:debug, "Skipping #{name} (not a git project)")
            end

            if is_skipped do
              broadcast_log(:debug, "Skipping #{name} (matches skip pattern)")
            end

            is_git
          end)

        # Apply priority ordering based on settings
        broadcast_log(
          :debug,
          "Found #{length(projects)} candidate projects, applying priority ordering"
        )

        projects = apply_priority_ordering(projects, dir)

        projects =
          case max_projects do
            :unlimited -> projects
            n -> Enum.take(projects, n)
          end

        Enum.map(projects, &Path.join(dir, &1))

      {:error, reason} ->
        Logger.error("Failed to list projects directory: #{inspect(reason)}")
        []
    end
  end

  defp apply_priority_ordering(projects, base_dir) do
    priority_mode = Settings.get_discovery_priority_mode()
    broadcast_log(:debug, "Priority mode: #{priority_mode}")

    case priority_mode do
      "alphabetical" ->
        Enum.sort(projects)

      "most_recently_modified" ->
        projects
        |> Enum.sort_by(
          fn project_name ->
            project_path = Path.join(base_dir, project_name)
            get_last_modified_time(project_path)
          end,
          :desc
        )

      "least_recently_scanned" ->
        projects
        |> Enum.sort_by(
          fn project_name ->
            project_path = Path.join(base_dir, project_name)

            case Projects.get_project_by_path(project_path) do
              nil -> nil
              project -> project.last_scanned
            end
          end,
          :asc
        )

      "random" ->
        Enum.shuffle(projects)

      _ ->
        # Default: alphabetical
        Enum.sort(projects)
    end
  end

  defp get_last_modified_time(dir_path) do
    # Get the most recent modification time in the project directory
    # We'll use a simple approach: get the max mtime of files in the root
    # This is a heuristic - could be improved to scan recursively
    case File.ls(dir_path) do
      {:ok, entries} ->
        entries
        |> Enum.map(fn entry ->
          path = Path.join(dir_path, entry)

          case File.stat(path) do
            {:ok, stat} ->
              stat.mtime

            {:error, reason} ->
              Logger.debug("Could not stat #{path}: #{inspect(reason)}")
              nil
          end
        end)
        |> Enum.filter(& &1)
        |> Enum.max(fn -> nil end)

      {:error, _} ->
        nil
    end
  end

  defp git_project?(path) do
    File.dir?(Path.join(path, ".git"))
  end

  defp register_project(path) do
    case Projects.get_or_create_project(path) do
      {:ok, project} ->
        Logger.info("Registered project: #{project.name}")
        broadcast_log(:info, "Registered project: #{project.name}")
        {:created, project}

      {:error, changeset} ->
        Logger.error("Failed to register project: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp discover_and_create_tasks(project, opts) do
    prompt = build_discovery_prompt(project)
    dry_run = Keyword.get(opts, :dry_run, false)

    if dry_run do
      Logger.info("[DRY RUN] Would run discovery for: #{project.name}")
      return_zero()
    end

    case run_pi_discovery(project.path, prompt) do
      {:ok, tasks} ->
        broadcast_log(:debug, "Parsed #{length(tasks)} tasks from pi output for #{project.name}")

        created =
          Enum.map(tasks, &create_task_from_discovery(project, &1))
          |> Enum.count(fn {status, _} -> status == :ok end)

        Projects.update_last_scanned(project)
        created

      {:error, reason} ->
        Logger.error("Discovery failed for #{project.name}: #{inspect(reason)}")
        broadcast_log(:error, "Discovery failed for #{project.name}: #{inspect(reason)}")
        return_zero()
    end
  end

  defp return_zero, do: 0

  defp build_discovery_prompt(project) do
    """
    You are a code analysis assistant. Examine the project at #{project.path} and identify potential tasks that could be automated.

    Look for:
    1. GitHub issues (if `gh` CLI is available)
    2. TODO/FIXME/HACK comments in code
    3. Failing tests or lint errors
    4. Outdated dependencies
    5. Existing planning docs (PLAN.md, CLAUDE.md, etc.)
    6. General code quality improvements

    Output your findings as a JSON array of task objects with the following structure:
    {
      "title": "Short task description",
      "description": "Detailed task specification that can be passed to pi -p",
      "priority": 1-10 (1 = highest priority, 10 = lowest)
    }

    Be selective and only suggest high-quality, actionable tasks. Aim for 3-5 tasks maximum.
    """
  end

  defp run_pi_discovery(project_path, prompt) do
    {command, args} = build_pi_command_args(prompt)

    case System.cmd(command, args,
           cd: project_path,
           stderr_to_stdout: false
         ) do
      {stdout, 0} ->
        parse_discovery_output(stdout)

      {stderr, exit_code} ->
        Logger.error("pi discovery failed with exit code #{exit_code}: #{stderr}")
        broadcast_log(:error, "pi discovery failed with exit code #{exit_code}")

        {:error, {:command_failed, exit_code, stderr}}
    end
  end

  @doc false
  def build_pi_command_args(prompt) do
    base_command = Application.get_env(:agent_queue, :pi_command, "pi")

    cmd_args = ["-p"]

    # Add provider/model if configured
    cmd_args =
      if provider = Application.get_env(:agent_queue, :pi_provider) do
        cmd_args ++ ["--provider", provider]
      else
        cmd_args
      end

    cmd_args =
      if model = Application.get_env(:agent_queue, :pi_model) do
        cmd_args ++ ["--model", model]
      else
        cmd_args
      end

    {base_command, cmd_args ++ [prompt]}
  end

  @doc false
  def parse_discovery_output(output) do
    with {:ok, tasks} when is_list(tasks) <- Jason.decode(output),
         {:ok, validated_tasks} <- validate_and_sanitize_tasks(tasks) do
      {:ok, validated_tasks}
    else
      {:ok, _} ->
        # Decoded but not a list, try to extract JSON array from text
        extract_json_array(output)

      {:error, _} ->
        # Parse failed, try to extract JSON array from mixed text
        extract_json_array(output)
    end
  end

  @max_tasks 10
  @max_string_length 10_000

  defp validate_and_sanitize_tasks(tasks) when length(tasks) > @max_tasks do
    Logger.warning("Received #{length(tasks)} tasks, limiting to #{@max_tasks}")
    validate_and_sanitize_tasks(Enum.take(tasks, @max_tasks))
  end

  defp validate_and_sanitize_tasks(tasks) do
    validated =
      tasks
      |> Enum.map(&validate_task/1)
      |> Enum.reduce({:ok, []}, fn
        {:ok, task}, {:ok, acc} ->
          {:ok, [task | acc]}

        {:error, reason}, _ ->
          Logger.warning("Skipping invalid task: #{inspect(reason)}")
          {:error, :invalid_task}
      end)

    case validated do
      {:ok, tasks} -> {:ok, Enum.reverse(tasks)}
      error -> error
    end
  end

  defp normalize_priority(priority) when is_integer(priority) do
    max(1, min(10, priority))
  end

  defp normalize_priority(priority) when is_binary(priority) do
    case Integer.parse(priority) do
      {int, _} -> max(1, min(10, int))
      :error -> 10
    end
  end

  defp normalize_priority(_), do: 10

  defp validate_task(task) when not is_map(task), do: {:error, :invalid_task}

  defp validate_task(task) do
    title = Map.get(task, "title", "Untitled task")
    description = Map.get(task, "description", "")

    cond do
      not is_binary(title) or byte_size(title) >= 500 ->
        {:error, :invalid_task}

      not is_binary(description) or byte_size(description) >= @max_string_length ->
        {:error, :invalid_task}

      true ->
        priority = normalize_priority(Map.get(task, "priority", 10))

        {:ok,
         %{
           title: String.trim(title),
           description: String.trim(description),
           priority: priority
         }}
    end
  end

  defp extract_json_array(output) do
    case Regex.run(~r/\[[\s\S]*\]/, output) do
      [json_array] ->
        parse_json_array(json_array)

      _ ->
        Logger.warning("Could not extract JSON array from discovery output")
        {:error, :parse_failed}
    end
  end

  defp parse_json_array(json_array) do
    case Jason.decode(json_array) do
      {:ok, tasks} when is_list(tasks) ->
        validate_and_sanitize_tasks(tasks)

      _ ->
        Logger.warning("Could not parse discovery output as task array")
        {:error, :parse_failed}
    end
  end

  defp create_task_from_discovery(project, task_attrs) do
    Tasks.create_task_for_project(project, %{
      title: task_attrs.title,
      description: task_attrs.description,
      priority: task_attrs.priority,
      source: "auto"
    })
  end
end
