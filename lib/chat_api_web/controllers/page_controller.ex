defmodule ChatApiWeb.PageController do
  use ChatApiWeb, :controller

  def chat_redirect(conn, params) do
    # Message form did a native POST; save message if body+with present, then redirect
    with_id = params["with"] || get_query_param(conn, "with")
    body = params["body"]
    user_id = get_session(conn, "user_id")

    path =
      if is_binary(with_id) and is_binary(body) and String.trim(body) != "" and is_binary(user_id) do
        if ChatApi.Store.user_exists?(user_id) and ChatApi.Store.user_exists?(with_id) do
          {:ok, msg} = ChatApi.Store.add_message(user_id, with_id, String.trim(body))
          topic = Enum.sort([user_id, with_id]) |> Enum.join(":")
          Phoenix.PubSub.broadcast(ChatApi.PubSub, "room:#{topic}", {:new_message, msg})
        end
        "/chat?with=#{URI.encode_www_form(with_id)}"
      else
        case conn.query_string do
          q when is_binary(q) and q != "" -> "/chat?" <> q
          _ -> ~p"/chat"
        end
      end

    redirect(conn, to: path)
  end

  defp get_query_param(conn, key) do
    conn.query_string
    |> Plug.Conn.Query.decode()
    |> Map.get(key)
  end

  def login(conn, %{"email" => email}) do
    email = String.trim(email)
    if email == "" do
      conn
      |> put_flash(:error, "Please enter your email")
      |> redirect(to: ~p"/")
    else
      user =
        case ChatApi.Store.get_user_by_email(email) do
          {:ok, u} -> u
          {:error, :not_found} -> elem(ChatApi.Store.create_user(email), 1)
        end

      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Welcome!")
      |> redirect(to: ~p"/chat")
    end
  end
end
