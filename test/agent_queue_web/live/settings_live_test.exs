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
end
