defmodule Mix.Tasks.Aq.Discover do
  use Mix.Task

  @shortdoc "Discover projects and tasks"

  @moduledoc """
  Discover projects in the configured directory and identify potential tasks.

  ## Examples

      mix aq.discover                    # Scan projects and discover tasks
      mix aq.discover --max-time 1800   # Maximum discovery time (seconds)
      mix aq.discover --dry-run         # Show what would be done without executing

  ## Options

    * `--max-time` - Maximum discovery time in seconds (default: 1800)
    * `--max-projects` - Maximum number of projects to scan (default: unlimited)
    * `--dry-run` - Show what would be done without executing
  """

  @impl true
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    # Parse arguments
    opts = parse_args(args)

    # Ensure the repo is available
    ensure_repo!()

    # Scan projects
    IO.puts("Scanning for projects...")
    {:ok, discovered_projects} = AgentQueue.Discovery.scan_projects(opts)
    IO.puts("Discovered #{discovered_projects} new projects")

    # Discover tasks
    IO.puts("Discovering tasks...")
    {:ok, discovered_tasks} = AgentQueue.Discovery.discover_all_tasks(opts)
    IO.puts("Discovered #{discovered_tasks} new tasks")

    IO.puts("\nDiscovery complete!")
  end

  defp parse_args(args) do
    {opts, _args, _errors} =
      OptionParser.parse(args,
        strict: [
          max_time: :integer,
          max_projects: :integer,
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
    Usage: mix aq.discover [options]

    Options:
      --max-time SECONDS      Maximum discovery time in seconds (default: 1800)
      --max-projects N       Maximum number of projects to scan (default: unlimited)
      --dry-run              Show what would be done without executing
      --help                 Show this help message
    """)
  end

  defp ensure_repo! do
    unless Process.whereis(AgentQueue.Repo) do
      raise "AgentQueue.Repo is not running. Make sure the database is configured and started."
    end
  end
end
