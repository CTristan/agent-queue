defmodule AgentQueue.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentQueueWeb.Telemetry,
      AgentQueue.Repo,
      {DNSCluster, query: Application.get_env(:agent_queue, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AgentQueue.PubSub},
      # Task supervisor for async discovery tasks
      {Task.Supervisor, name: AgentQueue.TaskSupervisor},
      # Start the Discoverer GenServer for project/task discovery
      AgentQueue.Discoverer,
      # Start the Runner GenServer for task execution
      AgentQueue.Runner,
      # Start to serve requests, typically the last entry
      AgentQueueWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AgentQueue.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, sup} ->
        # Ensure default settings are present after Repo starts
        AgentQueue.Settings.ensure_defaults()
        {:ok, sup}

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AgentQueueWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
