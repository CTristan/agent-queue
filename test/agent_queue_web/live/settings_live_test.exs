defmodule AgentQueueWeb.SettingsLiveTest do
  use AgentQueueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentQueue.Settings

  describe "save_settings" do
    test "persists valid settings and shows success message", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "20",
            "discovery_priority_mode" => "alphabetical",
            "discovery_debug_mode" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved successfully"
      assert Settings.get("discovery_max_projects") == "20"
      assert Settings.get("discovery_priority_mode") == "alphabetical"
      assert Settings.get("discovery_debug_mode") == "true"
    end

    test "shows error for max projects of zero", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "0",
            "discovery_priority_mode" => "alphabetical"
          }
        })
        |> render_submit()

      assert html =~ "Max projects must be a positive integer"
      refute Settings.get("discovery_max_projects") == "0"
    end

    test "shows error for non-numeric max projects", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "abc",
            "discovery_priority_mode" => "alphabetical"
          }
        })
        |> render_submit()

      assert html =~ "Max projects must be a positive integer"
      refute Settings.get("discovery_max_projects") == "abc"
    end
  end

  describe "task timeout setting" do
    test "persists timeout value", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "10",
            "discovery_priority_mode" => "most_recently_modified",
            "discovery_task_timeout" => "120"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved successfully"
      assert Settings.get("discovery_task_timeout") == "120"
    end

    test "shows error for non-numeric timeout", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "10",
            "discovery_priority_mode" => "most_recently_modified",
            "discovery_task_timeout" => "abc"
          }
        })
        |> render_submit()

      assert html =~ "Task timeout must be a positive integer"
    end
  end

  describe "discovery prompt setting" do
    test "persists custom prompt", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "10",
            "discovery_priority_mode" => "most_recently_modified",
            "discovery_prompt" => "Custom prompt for {{project_name}}"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved successfully"
      assert Settings.get_discovery_prompt() == "Custom prompt for {{project_name}}"
    end

    test "clears prompt when set to empty", %{conn: conn} do
      {:ok, _} = Settings.update_setting("discovery_prompt", "old prompt")

      {:ok, view, _} = live(conn, ~p"/settings")

      html =
        view
        |> form("form", %{
          "settings" => %{
            "discovery_max_projects" => "10",
            "discovery_priority_mode" => "most_recently_modified",
            "discovery_prompt" => ""
          }
        })
        |> render_submit()

      assert html =~ "Settings saved successfully"
      assert Settings.get_discovery_prompt() == nil
    end
  end
end
