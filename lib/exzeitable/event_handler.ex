defmodule Exzeitable.EventHandler do
  alias Phoenix.LiveView
  alias Exzeitable.Database

  @type socket :: Phoenix.LiveView.Socket.t()

  # "Clicking the hide button hides the column"
  @spec handle_event(String.t(), map, socket) :: {:noreply, socket}
  def handle_event("hide_column", %{"column" => column}, socket) do
    %{assigns: %{fields: fields}} = socket
    fields = Kernel.put_in(fields, [String.to_existing_atom(column), :hidden], true)

    {:noreply, LiveView.assign(socket, :fields, fields)}
  end

  # "Clicking the show button shows the column"
  def handle_event("show_column", %{"column" => column}, socket) do
    %{assigns: %{fields: fields}} = socket
    fields = Kernel.put_in(fields, [String.to_existing_atom(column), :hidden], false)

    {:noreply, LiveView.assign(socket, :fields, fields)}
  end

  # "Hide all the show buttons"
  def handle_event("hide_buttons", _, socket) do
    {:noreply, LiveView.assign(socket, :show_field_buttons, false)}
  end

  # "Show all the show buttons"
  def handle_event("show_buttons", _, socket) do
    {:noreply, LiveView.assign(socket, :show_field_buttons, true)}
  end

  # "Changes page when pagination buttons are clicked"
  def handle_event("change_page", %{"page" => page}, %{assigns: assigns} = socket) do
    new_value = %{page: String.to_integer(page)}

    socket =
      socket
      |> LiveView.assign(new_value)
      |> LiveView.assign(:list, Database.get_records(Map.merge(assigns, new_value)))

    {:noreply, socket}
  end

  # "Clicking the sort button sorts the column"
  def handle_event("sort_column", %{"column" => column}, %{assigns: assigns} = socket) do
    column = String.to_existing_atom(column)

    new_value =
      case assigns.order do
        [asc: ^column] -> %{order: [desc: column], page: 1}
        _ -> %{order: [asc: column], page: 1}
      end

    socket =
      socket
      |> LiveView.assign(new_value)
      |> LiveView.assign(:list, Database.get_records(Map.merge(assigns, new_value)))

    {:noreply, socket}
  end

  # "Typing into the search box... searches. Crazy, right?"
  def handle_event("search", %{"search" => %{"search" => search}}, socket) do
    socket =
      socket
      |> LiveView.assign(%{search: search, page: 1})
      |> maybe_get_records()

    {:noreply, socket}
  end

  # "Refresh periodically grabs new records from the database"
  def handle_info(:refresh, socket) do
    {:noreply, maybe_get_records(socket)}
  end

  def maybe_get_records(socket) do
    %{assigns: assigns} = socket

    if LiveView.connected?(socket) do
      socket
      |> LiveView.assign(:list, Database.get_records(assigns))
      |> LiveView.assign(:count, Database.get_record_count(assigns))
    else
      socket
      |> LiveView.assign(:list, [])
      |> LiveView.assign(:count, 0)
    end
  end

  def maybe_set_refresh(%{socket: %{assigns: %{refresh: refresh}}} = socket)
      when is_integer(refresh) do
    with true <- LiveView.connected?(socket),
         {:ok, _tref} <- :timer.send_interval(refresh, self(), :refresh) do
      socket
    else
      _ -> socket
    end
  end

  def maybe_set_refresh(socket) do
    socket
  end
end
