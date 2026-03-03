defmodule ChatApiWeb.UserController do
  use ChatApiWeb, :controller

  action_fallback ChatApiWeb.FallbackController

  def create(conn, %{"email" => email}) when is_binary(email) and email != "" do
    case ChatApi.Store.get_user_by_email(email) do
      {:ok, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: ChatApiWeb.UserJSON)
        |> render(:error, message: "User with this email already exists")

      {:error, :not_found} ->
        {:ok, user} = ChatApi.Store.create_user(email)

        conn
        |> put_status(:created)
        |> put_view(json: ChatApiWeb.UserJSON)
        |> render(:show, user: user)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ChatApiWeb.UserJSON)
    |> render(:error, message: "email is required and must be a non-empty string")
  end
end
