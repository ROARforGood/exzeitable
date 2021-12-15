defmodule TestWeb.ComponentTable do
  @moduledoc "User table in a component"
  alias TestWeb.Router.Helpers, as: Routes
  alias TestWeb.User

  use Phoenix.LiveView

  defmodule TableComponent do
    use Exzeitable.Component,
      repo: TestWeb.Repo,
      routes: Routes,
      path: :user_path,
      fields: [
        name: [],
        age: [label: "Years old", search: false]
      ],
      query: from(u in User),
      per_page: 5

    def render(assigns), do: ~L"<%= build_table(assigns) %>"
  end

  def mount(_, _, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <%= live_component TableComponent, id: :table %>
    """
  end
end
