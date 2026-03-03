defmodule ChatApiWeb.ChatLive do
  use ChatApiWeb, :live_view

  def mount(_params, session, socket) do
    user_id = session["user_id"]
    if !user_id || !ChatApi.Store.user_exists?(user_id) do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      {:ok, current_user} = ChatApi.Store.get_user(user_id)
      other_users = ChatApi.Store.list_users() |> Enum.reject(&(&1.id == user_id))

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:other_users, other_users)
       |> assign(:selected_user, nil)
       |> assign(:messages, [])
       |> assign(:message_body, "")
       |> assign(:topic, nil)
       |> assign(:users_in_room, [])
       |> assign(:users_typing, [])
       |> assign(:typing_timer_ref, nil)
       |> assign(:last_read_at_by_other, 0)}
    end
  end

  def handle_params(params, uri, socket) do
    # Query params could be in params or only in URI on initial load
    params = merge_query_params_from_uri(params, uri)
    with_user_id = params["with"]
    topic = with_user_id && conversation_topic(socket.assigns.current_user.id, with_user_id)
    {:noreply, maybe_select_conversation(socket, with_user_id, topic)}
  end

  def handle_event("select_user", %{"id" => id}, socket) do
    path = "/chat?with=#{URI.encode_www_form(id)}"
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("send_message", %{"body" => body}, socket) do
    body = String.trim(body)
    %{current_user: me, selected_user: other, topic: topic, messages: messages} = socket.assigns
    if body == "" or !other or !topic do
      {:noreply, socket}
    else
      {:ok, msg} = ChatApi.Store.add_message(me.id, other.id, body)
      Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:new_message, msg})
      # Clear typing state when sending
      presence_topic = "room_presence:#{topic}"
      ChatApiWeb.Presence.track(self(), presence_topic, me.id, %{
        email: me.email,
        typing: false
      })
      Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:typing, me.id, me.email, false})
      # Optimistic update so sender sees message immediately; other user gets it via broadcast
      {:noreply,
       socket
       |> cancel_typing_timer()
       |> assign(:messages, messages ++ [msg])
       |> assign(:message_body, "")}
    end
  end

  def handle_event("update_body", %{"body" => body}, socket) do
    socket =
      socket
      |> assign(:message_body, body || "")
      |> maybe_broadcast_typing()

    {:noreply, socket}
  end

  def handle_info(:stop_typing, socket) do
    %{topic: topic, current_user: user, typing_timer_ref: ref} = socket.assigns
    if topic && ref do
      presence_topic = "room_presence:#{topic}"
      ChatApiWeb.Presence.track(self(), presence_topic, user.id, %{
        email: user.email,
        typing: false
      })
      Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:typing, user.id, user.email, false})
    end
    {:noreply, assign(socket, :typing_timer_ref, nil)}
  end

  def handle_info({:new_message, message}, socket) do
    %{current_user: me, selected_user: other, topic: topic, messages: messages} = socket.assigns
    already_has = Enum.any?(messages, &(&1.id == message.id))
    if other && !already_has && (message.from_user_id == other.id || message.to_user_id == other.id) do
      socket = assign(socket, :messages, messages ++ [message])
      # If I'm the recipient, mark as read and notify sender
      socket =
        if message.to_user_id == me.id && topic do
          {:ok, last_at} = ChatApi.Store.mark_read(topic, me.id, message.inserted_at)
          Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:read_receipt, topic, me.id, last_at})
          socket
        else
          socket
        end
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:read_receipt, topic, reader_user_id, last_read_at}, socket) do
    %{topic: my_topic, selected_user: other, last_read_at_by_other: prev} = socket.assigns
    if my_topic == topic && other && reader_user_id == other.id do
      new_at = max(prev, last_read_at)
      {:noreply, assign(socket, :last_read_at_by_other, new_at)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", topic: topic}, socket) do
    if socket.assigns[:topic] && "room_presence:#{socket.assigns.topic}" == topic do
      presences = ChatApiWeb.Presence.list(topic)
      users_in_room = presence_metas_to_emails(presences)
      users_typing = presence_typing_emails(presences, socket.assigns.current_user.id)
      {:noreply,
       socket
       |> assign(:users_in_room, users_in_room)
       |> assign(:users_typing, users_typing)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:typing, user_id, email, is_typing}, socket) do
    %{current_user: me, selected_user: other, users_typing: current} = socket.assigns
    if other && user_id != me.id do
      users_typing =
        if is_typing do
          if email in current, do: current, else: [email | current] |> Enum.uniq()
        else
          List.delete(current, email)
        end
      {:noreply, assign(socket, :users_typing, users_typing)}
    else
      {:noreply, socket}
    end
  end

  defp maybe_select_conversation(socket, nil, _topic) do
    socket
    |> cancel_typing_timer()
    |> maybe_unsubscribe_all(socket.assigns[:topic])
    |> assign(:selected_user, nil)
    |> assign(:messages, [])
    |> assign(:topic, nil)
    |> assign(:users_in_room, [])
    |> assign(:users_typing, [])
    |> assign(:last_read_at_by_other, 0)
  end

  defp maybe_select_conversation(socket, other_id, topic) do
    case ChatApi.Store.get_user(other_id) do
      {:ok, other} ->
        messages = ChatApi.Store.get_conversation(socket.assigns.current_user.id, other_id)
        presence_topic = "room_presence:#{topic}"
        last_read_at_by_other = ChatApi.Store.get_last_read_at(topic, other_id)
        socket
        |> maybe_unsubscribe_all(socket.assigns[:topic])
        |> then(fn s ->
          if connected?(s) && topic do
            Phoenix.PubSub.subscribe(ChatApi.PubSub, "room:#{topic}")
            Phoenix.PubSub.subscribe(ChatApi.PubSub, presence_topic)
            ChatApiWeb.Presence.track(self(), presence_topic, s.assigns.current_user.id, %{
              email: s.assigns.current_user.email,
              typing: false
            })
            presences = ChatApiWeb.Presence.list(presence_topic)
            users_in_room = presence_metas_to_emails(presences)
            users_typing = presence_typing_emails(presences, s.assigns.current_user.id)
            # Mark current user as having read all messages in this conversation
            max_inserted = Enum.reduce(messages, 0, fn m, acc -> max(acc, m.inserted_at) end)
            if max_inserted > 0 do
              {:ok, last_at} = ChatApi.Store.mark_read(topic, s.assigns.current_user.id, max_inserted)
              Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:read_receipt, topic, s.assigns.current_user.id, last_at})
            end
            assign(s, :users_in_room, users_in_room)
            |> assign(:users_typing, users_typing)
          else
            s
          end
        end)
        |> assign(:selected_user, other)
        |> assign(:messages, messages)
        |> assign(:topic, topic)
        |> assign(:last_read_at_by_other, last_read_at_by_other)
      _ ->
        socket
    end
  end

  defp maybe_unsubscribe_all(socket, nil), do: socket
  defp maybe_unsubscribe_all(socket, topic) do
    Phoenix.PubSub.unsubscribe(ChatApi.PubSub, "room:#{topic}")
    Phoenix.PubSub.unsubscribe(ChatApi.PubSub, "room_presence:#{topic}")
    ChatApiWeb.Presence.untrack(self(), "room_presence:#{topic}", socket.assigns.current_user.id)
    socket
  end

  defp cancel_typing_timer(socket) do
    case socket.assigns[:typing_timer_ref] do
      ref when is_reference(ref) -> Process.cancel_timer(ref)
      _ -> :ok
    end
    assign(socket, :typing_timer_ref, nil)
  end

  defp maybe_broadcast_typing(socket) do
    %{topic: topic, current_user: user, typing_timer_ref: prev_ref} = socket.assigns
    if topic && connected?(socket) do
      if prev_ref, do: Process.cancel_timer(prev_ref)
      presence_topic = "room_presence:#{topic}"
      ChatApiWeb.Presence.track(self(), presence_topic, user.id, %{
        email: user.email,
        typing: true
      })
      Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:typing, user.id, user.email, true})
      ref = Process.send_after(self(), :stop_typing, 2_000)
      assign(socket, :typing_timer_ref, ref)
    else
      socket
    end
  end

  defp presence_typing_emails(presences, current_user_id) do
    presences
    |> Enum.reject(fn {user_id, _} -> user_id == current_user_id end)
    |> Enum.flat_map(fn {_, %{metas: metas}} ->
      Enum.filter(metas, & &1[:typing])
      |> Enum.map(& &1[:email])
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp presence_metas_to_emails(presences) do
    presences
    |> Map.values()
    |> Enum.flat_map(fn %{metas: metas} -> Enum.map(metas, & &1[:email]) end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp conversation_topic(a, b), do: Enum.sort([a, b]) |> Enum.join(":")

  defp merge_query_params_from_uri(params, nil), do: params
  defp merge_query_params_from_uri(params, uri) when is_binary(uri) do
    case URI.parse(uri).query do
      nil -> params
      query -> Map.merge(Plug.Conn.Query.decode(query), params)
    end
  end
  defp merge_query_params_from_uri(params, _), do: params

  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-8rem)] gap-4">
      <aside class="w-64 shrink-0 overflow-y-auto rounded-lg bg-white shadow">
        <h3 class="border-b p-3 font-medium text-gray-700">Chat with</h3>
        <ul class="divide-y">
          <%= for user <- @other_users do %>
            <li>
              <a
                href={"/chat?with=#{URI.encode_www_form(user.id)}"}
                data-phx-link="patch"
                data-phx-link-state="push"
                class={[
                  "block w-full px-3 py-2 text-left text-sm hover:bg-gray-50",
                  @selected_user && @selected_user.id == user.id && "bg-indigo-50 font-medium"
                ]}
              >
                <%= user.email %>
              </a>
            </li>
          <% end %>
        </ul>
        <%= if @other_users == [] do %>
          <p class="p-3 text-sm text-gray-500">No other users yet.</p>
        <% end %>
      </aside>
      <section class="flex flex-1 flex-col rounded-lg bg-white shadow">
        <%= if @selected_user do %>
          <div class="border-b p-3">
            <div class="font-medium text-gray-700">
              Conversation with <%= @selected_user.email %>
            </div>
            <%= if @users_in_room != [] do %>
              <p class="mt-1 text-xs text-green-600">
                <%= Enum.join(@users_in_room, ", ") %> in this chat
              </p>
            <% end %>
            <%= if @users_typing != [] do %>
              <p class="mt-1 text-xs italic text-gray-500">
                <%= Enum.join(@users_typing, ", ") %> <%= if length(@users_typing) == 1, do: "is", else: "are" %> typing...
              </p>
            <% end %>
          </div>
          <div id="messages" class="min-h-[200px] flex-1 overflow-y-auto p-4 space-y-2">
            <%= for msg <- @messages do %>
              <div
                class={[
                  "rounded-lg px-3 py-2 max-w-[80%] flex items-baseline gap-2 flex-wrap",
                  msg.from_user_id == @current_user.id && "ml-auto bg-indigo-600 text-white",
                  msg.from_user_id != @current_user.id && "bg-gray-100 text-gray-800"
                ]}
              >
                <span class={[
                  "text-xs font-medium shrink-0 border-r pr-2",
                  msg.from_user_id == @current_user.id && "text-indigo-200 border-indigo-400",
                  msg.from_user_id != @current_user.id && "text-gray-500 border-gray-300"
                ]}>
                  <%= if msg.from_user_id == @current_user.id, do: @current_user.email, else: @selected_user.email %>
                </span>
                <span class="text-sm break-words flex-1 min-w-0"><%= msg.body %></span>
                <%= if msg.from_user_id == @current_user.id do %>
                  <span class={[
                    "text-xs shrink-0",
                    msg.inserted_at <= @last_read_at_by_other && "text-indigo-200",
                    msg.inserted_at > @last_read_at_by_other && "text-indigo-300"
                  ]} title={if msg.inserted_at <= @last_read_at_by_other, do: "Read", else: "Sent"}>
                    <%= if msg.inserted_at <= @last_read_at_by_other do %>
                      Read
                    <% else %>
                      Sent
                    <% end %>
                  </span>
                <% end %>
              </div>
            <% end %>
            <%= if @messages == [] do %>
              <p class="text-sm text-gray-400 py-4">No messages yet. Send one below.</p>
            <% end %>
          </div>
          <.form for={%{}} action="#" method="post" phx-submit="send_message" phx-change="update_body" class="border-t p-3">
            <div class="flex gap-2">
              <input
                type="text"
                name="body"
                value={@message_body}
                placeholder="Type a message..."
                class="flex-1 rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              />
              <.button type="submit">Send</.button>
            </div>
          </.form>
        <% else %>
          <div class="flex flex-1 items-center justify-center text-gray-500">
            Select a user to start chatting
          </div>
        <% end %>
      </section>
    </div>
    """
  end
end
