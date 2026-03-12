defmodule Mix.Tasks.Aq.Run do
  use Mix.Task

  @shortdoc "Execute approved tasks"

  @moduledoc """
  Execute approved tasks within a time budget.

  ## Examples

      mix aq.run                          # Run with default budget (240 minutes)
      mix aq.run --budget 60              # Run with 60 minute budget
      mix aq.run --dry-run               # Show what would be executed

  ## Options

    * `--budget` - Time budget in minutes (default: 240)
    * `--dry-run` - Show what would be executed without running
  """

  @impl true
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    # Parse arguments
    opts = parse_args(args)

    # Ensure the repo is available
    ensure_repo!()

    # Start the runner
    budget_minutes = Keyword.get(opts, :budget, 240)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts(
      "Starting task execution with #{budget_minutes} minute budget (dry_run: #{dry_run})..."
    )

    # Subscribe to runner status
    AgentQueue.Runner.subscribe_status()

    # Start the run
    AgentQueue.Runner.start_run(budget_minutes: budget_minutes, dry_run: dry_run)

    # Wait for runner to finish
    wait_for_completion()
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          budget: :integer,
          dry_run: :boolean,
          help: :boolean
        ]
      )

    if Keyword.get(opts, :help) do
      print_help()
      System.halt(0)
    end

    opts
  end

  defp print_help do
    IO.puts("""
    Usage: mix aq.run [options]

    Options:
      --budget MINUTES        Time budget in minutes (default: 240)
      --dry-run               Show what would be executed without running
      --help                  Show this help message
    """)
  end

  defp ensure_repo! do
    unless Process.whereis(AgentQueue.Repo) do
      raise "AgentQueue.Repo is not running. Make sure the database is configured and started."
    end
  end

  defp wait_for_completion do
    receive do
      {:runner_status, status} ->
        if status.current_task do
          IO.puts("Running task: #{status.current_task.title}")
          IO.puts("Budget remaining: #{div(status.budget_remaining_seconds, 60)} minutes")
        end

        if status.running do
          wait_for_completion()
        else
          IO.puts("\nTask execution complete!")
        end
    after
      5000 ->
        # Keepalive check
        status = AgentQueue.Runner.status()

        if status.running do
          wait_for_completion()
        else
          IO.puts("\nTask execution complete!")
        end
    end
  end
end
