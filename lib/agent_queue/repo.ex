defmodule AgentQueue.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :agent_queue,
    adapter: Ecto.Adapters.Postgres
end
