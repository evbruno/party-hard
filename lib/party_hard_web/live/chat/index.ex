defmodule PartyHardWeb.LiveChat.Index do
  use PartyHardWeb, :live_view
  require Logger

  alias PartyHard.EchoServer.Message, as: ChatMessage
  alias PartyHard.EchoServer

  @initial_data %{"message" => nil, "delay" => 1000}

  @impl true
  def mount(_params, %{"current_user" => cu} = session, socket) do
    Logger.info("Mount with session #{inspect(session)}")

    {:ok,
     socket
     |> assign(:current_user, cu)
     |> assign(:loading?, true)
     |> assign(:empty?, true)
     |> assign(:form, to_form(@initial_data))
     |> start_async(:load_history, fn -> load_chat_history(cu) end)
     |> stream(:messages, []), temporary_assigns: [form: nil]}
  end

  # moved to index.html.heex
  # @impl true
  # def render(assigns) do
  # end

  @impl true
  def handle_event("send", params, socket) do
    delay = parse_delay(params["delay"])
    msg = EchoServer.echo_message(socket.assigns.current_user, params["message"], delay)

    {
      :noreply,
      socket
      |> assign(:form, to_form(%{"message" => "", "delay" => delay}))
      |> put_flash(:info, "Message sent")
      |> prepend_message(msg)
    }
  end

  @impl true
  def handle_event("broadcast", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "FIXME: not impl. yet 🤦🏻‍♂️")}
  end

  @impl true
  def handle_event(
        "update_delay",
        %{"_target" => ["delay"], "delay" => d, "message" => m},
        socket
      ) do
    socket = assign(socket, form: to_form(%{"delay" => d, "message" => m}))
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_delay", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("signout", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/chat/off")}
  end

  defp parse_delay(delay) do
    case Integer.parse(delay) do
      :error ->
        Logger.warning("Error parsing delay from #{inspect(delay)}")
        0

      {n, _} ->
        n
    end
  end

  @impl true
  def handle_info({:echo_reply, %ChatMessage{} = new_msg} = _payload, socket) do
    {:noreply, prepend_message(socket, new_msg)}
  end

  defp prepend_message(socket, new_msg) do
    socket
    |> assign(:loading?, false)
    |> assign(:empty?, false)
    |> stream_insert(:messages, new_msg, at: 0)
  end

  @impl true
  def handle_async(:load_history, {:ok, %{history: messages}} = _payload, socket) do
    socket =
      Enum.reduce(messages, socket, fn msg, sock ->
        stream_insert(sock, :messages, msg, at: -1)
      end)

    {:noreply,
     socket
     |> assign(:loading?, false)
     |> assign(:empty?, Enum.empty?(messages))}
  end

  defp load_chat_history(current_user) do
    history = EchoServer.load_history(current_user)

    %{history: history.messages}
  end
end
