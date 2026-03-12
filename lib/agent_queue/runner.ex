defmodule AgentQueue.Runner do
  @moduledoc """
  GenServer for executing approved tasks.
  """

  use GenServer
  require Logger

  alias AgentQueue.{Runs, Tasks}
  alias AgentQueue.Tasks.Task, as: TaskRecord

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start running approved tasks within a time budget.

  ## Examples

      iex> AgentQueue.Runner.start_run(budget_minutes: 60)
      :ok
  """
  def start_run(opts \\ []) do
    GenServer.cast(__MODULE__, {:start_run, opts})
  end

  @doc """
  Stop the current run.

  ## Examples

      iex> AgentQueue.Runner.stop_run()
      :ok
  """
  def stop_run do
    GenServer.cast(__MODULE__, :stop_run)
  end

  @doc """
  Get the current run status.

  ## Examples

      iex> AgentQueue.Runner.status()
      %{running: true, current_task: nil, remaining_budget: 1800}
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Subscribe to run status updates.

  ## Examples

      iex> Phoenix.PubSub.subscribe(AgentQueue.PubSub, "runner:status")
      :ok
  """
  def subscribe_status do
    Phoenix.PubSub.subscribe(AgentQueue.PubSub, "runner:status")
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    state = %{
      running: false,
      current_task: nil,
      current_run: nil,
      budget_remaining_seconds: 0,
      dry_run: Keyword.get(opts, :dry_run, false)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _, state) do
    {:reply,
     %{
       running: state.running,
       current_task: state.current_task,
       budget_remaining_seconds: state.budget_remaining_seconds
     }, state}
  end

  @impl true
  def handle_cast({:start_run, opts}, state) do
    if state.running do
      Logger.warning("Runner is already running")
      {:noreply, state}
    else
      budget_minutes = Keyword.get(opts, :budget_minutes, 240)
      dry_run = Keyword.get(opts, :dry_run, state.dry_run)

      Logger.info("Starting runner with budget: #{budget_minutes} minutes (dry_run: #{dry_run})")

      new_state = %{
        state
        | running: true,
          budget_remaining_seconds: budget_minutes * 60,
          dry_run: dry_run
      }

      broadcast_status(new_state)
      Process.send(self(), :process_next_task, [])

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast(:stop_run, state) do
    if state.running do
      Logger.info("Stopping runner")
      new_state = %{state | running: false, current_task: nil, current_run: nil}
      broadcast_status(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:process_next_task, state) do
    cond do
      not state.running ->
        {:noreply, state}

      state.budget_remaining_seconds <= 0 ->
        Logger.info("Budget exhausted, stopping runner")
        new_state = %{state | running: false, current_task: nil, current_run: nil}
        broadcast_status(new_state)
        {:noreply, new_state}

      true ->
        case Tasks.list_approved_tasks() do
          [] ->
            Logger.info("No approved tasks, stopping runner")
            new_state = %{state | running: false, current_task: nil, current_run: nil}
            broadcast_status(new_state)
            {:noreply, new_state}

          [task | _] ->
            Logger.info("Executing task: #{task.title}")
            execute_task(task, state)
        end
    end
  end

  @impl true
  def handle_info({:task_complete, result}, state) do
    Logger.info("Task completed: #{inspect(result)}")

    new_state = %{
      state
      | current_task: nil,
        current_run: nil,
        budget_remaining_seconds: state.budget_remaining_seconds - result.duration_seconds
    }

    broadcast_status(new_state)
    Process.send(self(), :process_next_task, [])

    {:noreply, new_state}
  end

  defp execute_task(%TaskRecord{} = task, state) do
    # Mark task as running
    {:ok, task} = Tasks.start_task(task)

    # Create a branch for the task
    branch_name = "aq/#{task.id}"

    create_git_branch(task.project.path, branch_name)

    # Start a run
    {command, args} = build_pi_command_args(task.description)
    command_string = Enum.join([command | args], " ")

    {:ok, run} = Runs.start_run(task, command_string)

    new_state = %{state | current_task: task, current_run: run}
    broadcast_status(new_state)

    if state.dry_run do
      Logger.info("[DRY RUN] Would execute: #{command_string}")

      Process.send(self(), {:task_complete, %{duration_seconds: 0}}, [])
      {:noreply, new_state}
    else
      # Execute the task in a supervised task
      Task.start(fn ->
        result = execute_command(task.project.path, {command, args})

        # Complete the run
        Runs.complete_run(run, %{
          exit_code: result.exit_code,
          stdout: result.stdout,
          stderr: result.stderr
        })

        # Update task status
        update_task_status(task, result.exit_code)

        send(__MODULE__, {:task_complete, %{duration_seconds: result.duration_seconds}})
      end)

      {:noreply, new_state}
    end
  end

  defp update_task_status(task, 0), do: Tasks.mark_for_review(task)
  defp update_task_status(task, _), do: Tasks.fail_task(task)

  defp create_git_branch(project_path, branch_name) do
    case System.cmd("git", ["checkout", "-b", branch_name],
           cd: project_path,
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        :ok

      {stdout, _} ->
        if String.contains?(stdout, "already exists") do
          System.cmd("git", ["checkout", branch_name],
            cd: project_path,
            stderr_to_stdout: true
          )

          :ok
        else
          Logger.error("Failed to create git branch #{branch_name}: #{stdout}")
          {:error, stdout}
        end
    end
  end

  @doc false
  def build_pi_command_args(description) do
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

    {base_command, cmd_args ++ [description]}
  end

  defp execute_command(project_path, {command, args}) do
    start_time = System.monotonic_time(:second)

    {output, exit_code} =
      System.cmd(command, args,
        cd: project_path,
        stderr_to_stdout: true
      )

    end_time = System.monotonic_time(:second)
    duration = end_time - start_time

    %{
      stdout: output,
      stderr: "",
      exit_code: exit_code,
      duration_seconds: duration
    }
  rescue
    e ->
      Logger.error("Command execution failed: #{inspect(e)}")

      %{
        stdout: "",
        stderr: Exception.message(e),
        exit_code: -1,
        duration_seconds: 0
      }
  end

  defp broadcast_status(state) do
    Phoenix.PubSub.broadcast(
      AgentQueue.PubSub,
      "runner:status",
      {:runner_status,
       %{
         running: state.running,
         current_task:
           state.current_task && %{id: state.current_task.id, title: state.current_task.title},
         budget_remaining_seconds: state.budget_remaining_seconds
       }}
    )
  end
end
