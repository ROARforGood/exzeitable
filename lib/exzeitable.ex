defmodule Exzeitable do
  @moduledoc """
  # Exzeitable. Check README for usage instructions.
  """

  @doc "Expands into the gigantic monstrosity that is Exzeitable"
  defmacro __using__(opts) do
    alias Exzeitable.Parameters

    record_source =
      opts
      |> Keyword.get(:record_source, Exzeitable.Database)
      |> Macro.expand(__CALLER__)

    search_string =
      Keyword.get_lazy(opts, :search_string, fn ->
        opts
        |> Parameters.set_fields()
        |> record_source.tsvector_string()
      end)

    # coveralls-ignore-stop

    quote do
      use Phoenix.LiveView
      use Phoenix.HTML
      import Ecto.Query
      import Phoenix.LiveView.Helpers
      alias Exzeitable.{Filter, Format, HTML, Parameters, Validation}
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

      def prefix_search(search) do
        unquote(record_source).prefix_search(search)
      end

      @spec live_table(Plug.Conn.t(), keyword) :: {:safe, iolist}
      def live_table(conn, opts \\ []) do
        live_render(conn, __MODULE__, setup(opts))
      end

      def setup(opts \\ []) do
        [
          # Live component ID
          id: Keyword.get(unquote(opts), :id, 1),
          session: Parameters.process(opts, unquote(opts), __MODULE__)
        ]
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

        {:ok, socket} = mounted(socket)
        {:ok, refresh(socket)}
      end

      def mounted(socket), do: {:ok, socket}
      defoverridable mounted: 1

      def refresh(socket) do
        socket
        |> maybe_get_records()
        |> maybe_set_refresh()
      end

      @doc "Clicking the hide button hides the column"
      @spec handle_event(String.t(), map, socket) :: {:noreply, socket}
      def handle_event("hide_column", %{"column" => column}, socket) do
        %{assigns: %{fields: fields}} = socket
        fields = Kernel.put_in(fields, [String.to_existing_atom(column), :hidden], true)

        {:noreply, assign(socket, :fields, fields)}
      end

      @doc "Clicking the show button shows the column"
      def handle_event("show_column", %{"column" => column}, socket) do
        %{assigns: %{fields: fields}} = socket
        fields = Kernel.put_in(fields, [String.to_existing_atom(column), :hidden], false)

        {:noreply, assign(socket, :fields, fields)}
      end

      @doc "Hide all the show buttons"
      def handle_event("hide_buttons", _, socket) do
        {:noreply, assign(socket, :show_field_buttons, false)}
      end

      @doc "Show all the show buttons"
      def handle_event("show_buttons", _, socket) do
        {:noreply, assign(socket, :show_field_buttons, true)}
      end

      @doc "Changes page when pagination buttons are clicked"
      def handle_event("change_page", %{"page" => page}, %{assigns: assigns} = socket) do
        new_value = %{page: String.to_integer(page)}

        socket =
          socket
          |> assign(new_value)
          |> assign(:list, get_records(Map.merge(assigns, new_value)))

        {:noreply, socket}
      end

      @doc "Clicking the sort button sorts the column"
      def handle_event("sort_column", %{"column" => column}, %{assigns: assigns} = socket) do
        column = String.to_existing_atom(column)

        new_value =
          case assigns.order do
            [asc: ^column] -> %{order: [desc: column], page: 1}
            _ -> %{order: [asc: column], page: 1}
          end

        socket =
          socket
          |> assign(new_value)
          |> assign(:list, get_records(Map.merge(assigns, new_value)))

        {:noreply, socket}
      end

      @doc "Typing into the search box... searches. Crazy, right?"
      def handle_event("search", %{"search" => %{"search" => search}}, socket) do
        socket =
          socket
          |> assign(%{search: search, page: 1})
          |> maybe_get_records()

        {:noreply, socket}
      end

      @doc "Refresh periodically grabs new records from the database"
      def handle_info(:refresh, socket) do
        {:noreply, maybe_get_records(socket)}
      end

      defp maybe_get_records(socket) do
        %{assigns: assigns} = socket

        if connected?(socket) do
          socket
          |> assign(:list, get_records(assigns))
          |> assign(:count, get_record_count(assigns))
        else
          socket
          |> assign(:list, [])
          |> assign(:count, 0)
        end
      end

      defp maybe_set_refresh(%{socket: %{assigns: %{refresh: refresh}}} = socket)
           when is_integer(refresh) do
        with true <- connected?(socket),
             {:ok, _tref} <- :timer.send_interval(refresh, self(), :refresh) do
          socket
        else
          _ -> socket
        end
      end

      defp maybe_set_refresh(socket) do
        socket
      end

      # Need to unquote the search string because string interpolation is not allowed.
      @spec do_search(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
      def do_search(query, search) do
        prefixed_search = unquote(record_source).prefix_search(search)

        where(
          query,
          fragment(
            unquote(search_string),
            ^prefixed_search
          )
        )
      end

      defp get_records(assigns) do
        unquote(record_source).get_records(assigns)
      end

      defp get_record_count(assigns) do
        unquote(record_source).get_record_count(assigns)
      end
    end
  end
end
