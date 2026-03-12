defmodule AgentQueue.Discoverer do
  @moduledoc """
  GenServer for managing project and task discovery in the background.
  """

  use GenServer
  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start discovery of projects and tasks.

  ## Examples

      iex> AgentQueue.Discoverer.start_discovery()
      :ok

      iex> AgentQueue.Discoverer.start_discovery(max_time_seconds: 600)
      :ok
  """
  def start_discovery(opts \\ []) do
    GenServer.cast(__MODULE__, {:start_discovery, opts})
  end

  @doc """
  Get the current discovery status.

  ## Examples

      iex> AgentQueue.Discoverer.status()
      %{discovering: false, stage: nil, discovered_projects: 0, discovered_tasks: 0}
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Subscribe to discovery status updates.

  ## Examples

      iex> Phoenix.PubSub.subscribe(AgentQueue.PubSub, "discoverer:status")
      :ok
  """
  def subscribe_status do
    Phoenix.PubSub.subscribe(AgentQueue.PubSub, "discoverer:status")
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    state = %{
      discovering: false,
      stage: nil,
      discovered_projects: 0,
      discovered_tasks: 0,
      max_time_seconds: Keyword.get(opts, :max_time_seconds, 30 * 60),
      start_time: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _, state) do
    {:reply,
     %{
       discovering: state.discovering,
       stage: state.stage,
       discovered_projects: state.discovered_projects,
       discovered_tasks: state.discovered_tasks,
       elapsed_seconds:
         if(state.start_time, do: System.monotonic_time(:second) - state.start_time, else: 0)
     }, state}
  end

  @impl true
  def handle_cast({:start_discovery, opts}, state) do
    if state.discovering do
      Logger.warning("Discovery is already running")
      {:noreply, state}
    else
      max_time = Keyword.get(opts, :max_time_seconds, state.max_time_seconds)

      Logger.info("Starting discovery (max time: #{max_time}s)")

      new_state = %{
        state
        | discovering: true,
          stage: "scanning_projects",
          discovered_projects: 0,
          discovered_tasks: 0,
          max_time_seconds: max_time,
          start_time: System.monotonic_time(:second)
      }

      broadcast_status(new_state)
      Process.send(self(), :scan_projects, [])

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:discovery_complete, discovered_tasks}, state) do
    Logger.info(
      "Discovery complete! Found #{state.discovered_projects} projects and #{discovered_tasks} tasks"
    )

    new_state = %{
      state
      | discovering: false,
        stage: nil,
        discovered_tasks: discovered_tasks
    }

    broadcast_status(new_state)
    Phoenix.PubSub.broadcast(AgentQueue.PubSub, "tasks:update", {:tasks_updated, :now})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:discovery_failed, reason}, state) do
    Logger.error("Discovery failed: #{inspect(reason)}")

    new_state = %{state | discovering: false, stage: nil}
    broadcast_status(new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:scan_projects, state) do
    new_state = %{state | stage: "scanning_projects"}
    broadcast_status(new_state)

    try do
      {:ok, discovered_projects} = AgentQueue.Discovery.scan_projects(max_projects: :unlimited)
      Logger.info("Discovered #{discovered_projects} new projects")
      new_state = %{state | discovered_projects: discovered_projects, stage: "discovering_tasks"}
      broadcast_status(new_state)
      Process.send(self(), :discover_tasks, [])
      {:noreply, new_state}
    rescue
      error ->
        Logger.error("Discovery failed during project scan: #{inspect(error)}")
        GenServer.cast(__MODULE__, {:discovery_failed, error})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:discover_tasks, state) do
    new_state = %{state | stage: "discovering_tasks"}
    broadcast_status(new_state)

    Task.Supervisor.start_child(AgentQueue.TaskSupervisor, fn ->
      try do
        {:ok, discovered_tasks} =
          AgentQueue.Discovery.discover_all_tasks(max_time_seconds: state.max_time_seconds)

        Logger.info("Discovered #{discovered_tasks} new tasks")
        GenServer.cast(__MODULE__, {:discovery_complete, discovered_tasks})
      rescue
        error ->
          Logger.error("Discovery failed: #{inspect(error)}")
          GenServer.cast(__MODULE__, {:discovery_failed, error})
      end
    end)

    {:noreply, state}
  end

  defp broadcast_status(state) do
    Phoenix.PubSub.broadcast(
      AgentQueue.PubSub,
      "discoverer:status",
      {:discoverer_status,
       %{
         discovering: state.discovering,
         stage: state.stage,
         discovered_projects: state.discovered_projects,
         discovered_tasks: state.discovered_tasks,
         elapsed_seconds:
           if(state.start_time, do: System.monotonic_time(:second) - state.start_time, else: 0)
       }}
    )
  end
end
