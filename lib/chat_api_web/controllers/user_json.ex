defmodule ChatApiWeb.UserJSON do
  def show(%{user: user}) do
    %{id: user.id, email: user.email}
  end

  def show(%{users: users}) do
    %{users: Enum.map(users, &%{id: &1.id, email: &1.email})}
  end

  def error(%{message: message}) do
    %{error: message}
  end
end
