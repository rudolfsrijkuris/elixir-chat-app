defmodule ChatApiWeb.RoomChannel do
  use ChatApiWeb, :channel

  @impl true
  def join("room:" <> topic, _params, socket) do
    Phoenix.PubSub.subscribe(ChatApi.PubSub, "room:#{topic}")
    {:ok, assign(socket, :topic, topic)}
  end

  @impl true
  def handle_in("new_message", %{"to_user_id" => to_user_id, "body" => body}, socket) do
    from_user_id = socket.assigns.user_id

    # Ensure this user is part of this conversation topic (room:user1:user2)
    topic = Enum.sort([from_user_id, to_user_id]) |> Enum.join(":")
    if socket.assigns.topic != topic do
      {:reply, {:error, %{reason: "not in this conversation"}}, socket}
    else
      case ChatApi.Store.add_message(from_user_id, to_user_id, body) do
        {:ok, message} ->
          Phoenix.PubSub.broadcast(
            ChatApi.PubSub,
            "room:#{topic}",
            {:new_message, message}
          )
          {:reply, {:ok, %{message: message}}, socket}

        _ ->
          {:reply, {:error, %{reason: "failed to save"}}, socket}
      end
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    push(socket, "new_message", %{
      id: message.id,
      from_user_id: message.from_user_id,
      to_user_id: message.to_user_id,
      body: message.body,
      inserted_at: message.inserted_at
    })
    {:noreply, socket}
  end
end
