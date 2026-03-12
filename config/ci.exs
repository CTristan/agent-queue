# CI environment configuration
import Config

# In CI, we want to be stricter with warnings and disable development features

# Configure your database (similar to test.exs for CI)
config :agent_queue, AgentQueue.Repo,
  username: System.get_env("PGUSER", "chris"),
  password: System.get_env("PGPASSWORD", ""),
  hostname: System.get_env("PGHOST", "localhost"),
  database: System.get_env("PGDATABASE", "agent_queue_ci"),
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

# Disable code reloading in CI
config :agent_queue, AgentQueueWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: false,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE", "ci_mode_secret_key_base_change_in_production")

# Disable live reload in CI
config :agent_queue, AgentQueueWeb.Endpoint, live_reload: []

# Configure agent queue for CI
config :agent_queue,
  projects_dir: System.user_home!() <> "/projects",
  default_time_budget_minutes: 240,
  discovery_max_time_minutes: 30,
  discovery_skip_patterns: [
    "node_modules",
    ".git",
    "target",
    "_build",
    "deps",
    ".elixir_ls",
    "vendor"
  ],
  pi_command: "pi",
  pi_provider: nil,
  pi_model: nil

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Configure logger for CI
config :logger, level: :warning

# Initialize plugs at compile time for faster compilation in CI
config :phoenix, :plug_init_mode, :compile
