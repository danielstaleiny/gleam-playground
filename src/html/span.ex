defmodule Html.Span do
  use Phoenix.Component
  def render(assigns) do
    assigns
    |> IO.inspect()
    ~H"""
    <p>
      <%= @name %>
    </p>
    """
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  # def render(a) do
  #   render_(%{name: "Daniel"})
  # end
end
