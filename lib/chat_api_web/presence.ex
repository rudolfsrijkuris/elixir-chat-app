defmodule ChatApiWeb.Presence do
  @moduledoc """
  Tracks which users are currently viewing each chat room (conversation).
  """
  use Phoenix.Presence,
    otp_app: :chat_api,
    pubsub_server: ChatApi.PubSub
end
