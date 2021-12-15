defmodule Exzeitable do
  @moduledoc """
  # Exzeitable. Check README for usage instructions.
  """

  @doc "Expands into the gigantic monstrosity that is Exzeitable"
  defmacro __using__(opts) do
    alias Exzeitable.{Database, Parameters, EventHandler}

    search_string =
      opts
      |> Parameters.set_fields()
      |> Database.tsvector_string()

    # coveralls-ignore-stop

    quote do
      use Phoenix.LiveView
      use Phoenix.HTML
      import Ecto.Query
      alias Phoenix.LiveView.Helpers
      alias Exzeitable.{Database, Filter, Format, HTML, Parameters, Validation}
      @callback render(map) :: {:ok, iolist}
      @type socket :: Phoenix.LiveView.Socket.t()

      @doc """
      Convenience helper so LiveView doesn't have to be called directly

      ## Example

      ```
      <%= YourAppWeb.Live.Site.live_table(@conn, query: @query) %>
      ```

      """
      defdelegate build_table(assigns), to: HTML, as: :build
      defdelegate handle_event(event, params, socket), to: EventHandler
      defdelegate handle_info(info, socket), to: EventHandler

      @spec live_table(Plug.Conn.t(), keyword) :: {:safe, iolist}
      def live_table(conn, opts \\ []) do
        Helpers.live_render(conn, __MODULE__,
          # Live component ID
          id: Keyword.get(unquote(opts), :id, 1),
          session: Parameters.process(opts, unquote(opts), __MODULE__)
        )
      end

      ###########################
      ######## CALLBACKS ########
      ###########################

      @doc "Initial setup on page load"
      @spec mount(atom, map, socket) :: {:ok, socket}
      def mount(:not_mounted_at_router, assigns, socket) do
        assigns = Map.new(assigns, fn {k, v} -> {String.to_atom(k), v} end)

        socket =
          socket
          |> assign(assigns)
          |> EventHandler.maybe_get_records()
          |> EventHandler.maybe_set_refresh()

        {:ok, socket}
      end

      # Need to unquote the search string because string interpolation is not allowed.
      @spec do_search(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
      def do_search(query, search) do
        where(
          query,
          fragment(
            unquote(search_string),
            ^Database.prefix_search(search)
          )
        )
      end
    end
  end
end
