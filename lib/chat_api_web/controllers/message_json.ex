defmodule ChatApiWeb.MessageJSON do
  def show(%{message: message}) do
    %{
      id: message.id,
      from_user_id: message.from_user_id,
      to_user_id: message.to_user_id,
      body: message.body,
      inserted_at: message.inserted_at
    }
  end

  def show(%{messages: messages}) do
    %{
      messages:
        Enum.map(messages, fn m ->
          %{
            id: m.id,
            from_user_id: m.from_user_id,
            to_user_id: m.to_user_id,
            body: m.body,
            inserted_at: m.inserted_at
          }
        end)
    }
  end

  def error(%{message: message}) do
    %{error: message}
  end
end
