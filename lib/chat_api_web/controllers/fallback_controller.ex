defmodule ChatApiWeb.FallbackController do
  use ChatApiWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ChatApiWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: ChatApiWeb.ErrorJSON)
    |> render(:"500")
  end
end
