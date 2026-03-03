defmodule ChatApiWeb.UserSocket do
  use Phoenix.Socket

  channel "room:*", ChatApiWeb.RoomChannel

  @impl true
  def connect(%{"user_id" => raw_user_id}, socket, _connect_info) do
    # Query string decodes + as space; restore for lookup (and for IDs created before URL-safe fix)
    user_id = String.replace(raw_user_id, " ", "+")
    if ChatApi.Store.user_exists?(user_id) do
      {:ok, assign(socket, :user_id, user_id)}
    else
      :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
