defmodule ChatApiWeb.CoreComponents do
  @moduledoc false
  use Phoenix.Component

  attr :type, :string, default: "text"
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete disabled form max maxlength min minlength pattern placeholder readonly required size step)

  def input(assigns) do
    assigns = assign(assigns, :id, assigns[:id] || input_id(assigns))
    ~H"""
    <div class={["mb-3", @class]}>
      <.label for={@id} label={@label} />
      <input
        type={@type}
        name={@name || input_name(assigns)}
        id={@id}
        value={input_value(assigns)}
        placeholder={@placeholder}
        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        {@rest}
      />
    </div>
    """
  end

  attr :for, :string, default: nil
  attr :label, :string, default: nil

  def label(assigns) do
    ~H"""
    <%= if @label do %>
      <label for={@for} class="block text-sm font-medium text-gray-700"><%= @label %></label>
    <% end %>
    """
  end

  attr :type, :string, default: "submit"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp input_id(%{field: %Phoenix.HTML.FormField{id: id}}), do: id
  defp input_id(%{name: name}), do: "input-#{name}"

  defp input_name(%{field: %Phoenix.HTML.FormField{name: name}}), do: name
  defp input_name(%{name: name}), do: name

  defp input_value(%{field: %Phoenix.HTML.FormField{value: value}}), do: value
  defp input_value(%{value: value}), do: value
end
