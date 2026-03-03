defmodule ChatApiWeb.Plugs.NoCacheAssets do
  @moduledoc """
  In development, sets Cache-Control so /assets/* are not cached.
  Ensures the browser always loads the latest Tailwind-built app.css.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if String.starts_with?(conn.request_path, "/assets/") do
      conn
      |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> put_resp_header("pragma", "no-cache")
    else
      conn
    end
  end
end
