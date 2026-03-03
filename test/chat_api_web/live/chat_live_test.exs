defmodule ChatApiWeb.ChatLiveTest do
  use ChatApiWeb.ConnCase, async: true

  describe "mount and redirect" do
    test "redirects to / when no session user", %{conn: conn} do
      conn = get(conn, ~p"/chat")
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to / when session user does not exist in Store", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"user_id" => "nonexistent_id_12345"})
        |> get(~p"/chat")

      assert redirected_to(conn) == ~p"/"
    end
  end
end
