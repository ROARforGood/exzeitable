defmodule Exzeitable.Component do
  import Ecto.Query

  defmacro __using__(opts) do
    alias Exzeitable.{Database, Parameters, EventHandler}

    record_source =
      opts
      |> Keyword.get(:record_source, Database)
      |> Macro.expand(__CALLER__)

    search_string =
      opts
      |> Parameters.set_fields()
      |> record_source.tsvector_string()

    quote do
      use Phoenix.LiveComponent

      import Ecto.Query

      alias Exzeitable.{EventHandler, HTML}

      def mount(socket) do
        exzeitable_assigns =
          Exzeitable.Parameters.process([], unquote(opts), __MODULE__)
          |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.put(:socket, socket)

        socket =
          socket
          |> assign(exzeitable_assigns)

        {:ok, socket}
      end

      def update(assigns, socket) do
        socket =
          socket
          |> assign(Map.delete(assigns, :filter))
          |> maybe_change_filter(assigns)
          |> EventHandler.maybe_get_records()
          |> EventHandler.maybe_set_refresh()

        {:ok, socket}
      end

      defp maybe_change_filter(socket, assigns) do
        case Map.get(assigns, :filter) do
          nil -> socket
          filter -> assign(socket, :filter, filter)
        end
      end

      defdelegate build_table(assigns), to: HTML, as: :build
      defdelegate handle_event(event, params, socket), to: EventHandler

      def prefix_search(search) do
        unquote(record_source).prefix_search(search)
      end

      # Need to unquote the search string because string interpolation is not allowed.
      @spec handle_search(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
      def handle_search(query, search) do
        prefixed_search = prefix_search(search)

        where(
          query,
          fragment(
            unquote(search_string),
            ^prefixed_search
          )
        )
      end
    end
  end
end
