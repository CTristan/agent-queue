defmodule AgentQueue.DiscovererTest do
  use AgentQueue.DataCase

  defp wait_for_status(predicate, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    poll_interval = Keyword.get(opts, :poll_interval, 50)

    start_time = System.monotonic_time(:millisecond)

    Enum.reduce_while(1..div(timeout, poll_interval), nil, fn _, _ ->
      status = AgentQueue.Discoverer.status()

      if predicate.(status) do
        {:halt, status}
      else
        if System.monotonic_time(:millisecond) - start_time > timeout do
          raise "Timeout waiting for status to match predicate"
        end

        Process.sleep(poll_interval)
        {:cont, nil}
      end
    end)
  end

  describe "status/0" do
    test "returns current status" do
      status = AgentQueue.Discoverer.status()

      assert is_boolean(status.discovering)
      assert is_map(status)
      assert Map.has_key?(status, :stage)
      assert Map.has_key?(status, :discovered_projects)
      assert Map.has_key?(status, :discovered_tasks)
      assert Map.has_key?(status, :elapsed_seconds)
    end
  end

  describe "start_discovery/1" do
    test "starts discovery without error" do
      # Just verify it doesn't crash
      assert :ok = AgentQueue.Discoverer.start_discovery()
    end

    test "doesn't crash when discovery is already running" do
      # Start discovery
      assert :ok = AgentQueue.Discoverer.start_discovery()

      # Wait and verify it's actually running
      wait_for_status(fn s -> s.discovering end)

      # Try to start again - should not crash
      assert :ok = AgentQueue.Discoverer.start_discovery()

      # Verify state unchanged - still discovering
      status = AgentQueue.Discoverer.status()
      assert status.discovering
    end
  end

  describe "subscribe_status/0" do
    test "subscribes to discovery status updates" do
      assert :ok = Phoenix.PubSub.subscribe(AgentQueue.PubSub, "discoverer:status")
    end
  end
end
