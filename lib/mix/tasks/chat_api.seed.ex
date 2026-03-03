defmodule Mix.Tasks.ChatApi.Seed do
  @shortdoc "Creates demo users (john@doe.com, example@gmail.com) if they don't exist"
  @moduledoc """
  Seeds the in-memory store with two demo users so you can open two browsers and chat.

  Run after starting the app (e.g. in IEx) or the Store won't be running:

      iex -S mix
      Mix.Task.run("chat_api.seed")

  Or run before phx.server; the Store starts with the app.
  """
  use Mix.Task

  @demo_emails ["john@doe.com", "example@gmail.com"]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    for email <- @demo_emails do
      case ChatApi.Store.get_user_by_email(email) do
        {:ok, _} -> :ok
        {:error, :not_found} ->
          {:ok, user} = ChatApi.Store.create_user(email)
          Mix.shell().info("Created user: #{user.email} (id: #{user.id})")
      end
    end
  end
end
