defmodule ChatApiWeb.ErrorHTML do
  use ChatApiWeb, :html

  def render("404.html", assigns) do
    ~H"""
    <div class="rounded-md bg-red-50 p-4">
      <h2 class="text-lg font-medium text-red-800">Page not found</h2>
      <p class="mt-1 text-sm text-red-700">The page you are looking for does not exist.</p>
    </div>
    """
  end

  def render("500.html", assigns) do
    ~H"""
    <div class="rounded-md bg-red-50 p-4">
      <h2 class="text-lg font-medium text-red-800">Something went wrong</h2>
      <p class="mt-1 text-sm text-red-700">We're sorry, but something went wrong on our end.</p>
    </div>
    """
  end
end
