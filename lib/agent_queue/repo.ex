defmodule AgentQueue.Repo do
  use Ecto.Repo,
    otp_app: :agent_queue,
    adapter: Ecto.Adapters.Postgres
end
