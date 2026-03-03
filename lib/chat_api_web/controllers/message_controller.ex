defmodule ChatApiWeb.MessageController do
  use ChatApiWeb, :controller

  action_fallback ChatApiWeb.FallbackController

  def create(conn, %{"from_user_id" => from_id, "to_user_id" => to_id, "body" => body})
      when is_binary(body) and body != "" do
    with true <- ChatApi.Store.user_exists?(from_id),
         true <- ChatApi.Store.user_exists?(to_id) do
      {:ok, message} = ChatApi.Store.add_message(from_id, to_id, body)

      # Broadcast to WebSocket subscribers for real-time delivery
      Phoenix.PubSub.broadcast(
        ChatApi.PubSub,
        "room:#{conversation_topic(from_id, to_id)}",
        {:new_message, message}
      )

      conn
      |> put_status(:created)
      |> put_view(json: ChatApiWeb.MessageJSON)
      |> render(:show, message: message)
    else
      false ->
        conn
        |> put_status(:not_found)
        |> put_view(json: ChatApiWeb.ErrorJSON)
        |> render(:"404")
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ChatApiWeb.MessageJSON)
    |> render(:error, message: "from_user_id, to_user_id and body are required; body must be non-empty")
  end

  def conversation(conn, %{"user_id" => user_id, "with_user_id" => with_user_id}) do
    with true <- ChatApi.Store.user_exists?(user_id),
         true <- ChatApi.Store.user_exists?(with_user_id) do
      messages = ChatApi.Store.get_conversation(user_id, with_user_id)

      conn
      |> put_view(json: ChatApiWeb.MessageJSON)
      |> render(:show, messages: messages)
    else
      false ->
        conn
        |> put_status(:not_found)
        |> put_view(json: ChatApiWeb.ErrorJSON)
        |> render(:"404")
    end
  end

  def conversation(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ChatApiWeb.ErrorJSON)
    |> render(:error, message: "user_id and with_user_id are required")
  end

  defp conversation_topic(a, b), do: Enum.sort([a, b]) |> Enum.join(":")
end
