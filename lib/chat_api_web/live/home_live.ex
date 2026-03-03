defmodule ChatApiWeb.HomeLive do
  use ChatApiWeb, :live_view

  def mount(_params, session, socket) do
    # Only redirect if we have a valid session user (exists in store).
    # Stale user_id after server restart would otherwise cause redirect loop with /chat.
    if session["user_id"] && ChatApi.Store.user_exists?(session["user_id"]) do
      {:ok, push_navigate(socket, to: ~p"/chat")}
    else
      {:ok,
       socket
       |> assign(:email, "")
       |> assign(:error, nil)
       |> assign(:csrf_token, Plug.CSRFProtection.get_csrf_token())}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md rounded-lg bg-white p-6 shadow">
      <h2 class="mb-4 text-lg font-semibold text-gray-800">Enter your email to start</h2>
      <form action={~p"/login"} method="post" class="space-y-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <.label for="email" label="Email" />
        <input
          type="email"
          name="email"
          id="email"
          value={@email}
          placeholder="you@example.com"
          required
          class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
        <%= if @error do %>
          <p class="text-sm text-red-600"><%= @error %></p>
        <% end %>
        <.button type="submit">Continue</.button>
      </form>
    </div>
    """
  end
end
