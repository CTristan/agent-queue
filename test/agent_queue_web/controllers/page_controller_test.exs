defmodule AgentQueueWeb.PageControllerTest do
  use AgentQueueWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Projects"
  end
end
