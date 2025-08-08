defmodule PartyHardWeb.LiveChat.ChatMessage do
  defstruct id: -1, date: "", content: "", sender: "", broadcast: false

  def now(sender, content, delta \\ 0) do
    %__MODULE__{
      id: System.unique_integer([:positive]),
      date: NaiveDateTime.utc_now() |> NaiveDateTime.add(delta),
      content: content,
      sender: sender
    }
  end
end

defmodule PartyHardWeb.LiveChat.Index do
  use PartyHardWeb, :live_view
  require Logger

  alias PartyHardWeb.LiveChat.ChatMessage

  @initial_data %{"message" => nil, "delay" => 1000}

  @impl true
  def mount(_params, %{"current_user" => cu} = session, socket) do
    Logger.debug("Mount with session #{inspect(session)}")

    {:ok,
     socket
     |> assign(:current_user, cu)
     |> assign(:loading, true)
     |> assign(:form, to_form(@initial_data))
     |> start_async(:load_history, fn -> load_chat_history(cu) end)
     |> stream(:messages, []), temporary_assigns: [form: nil]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Welcome user <strong>{@current_user}</strong>
        <:subtitle>This is a echo server (in memory history)</:subtitle>
      </.header>

      <.form id="message-form" for={@form} phx-submit="send">
        <.input
          field={@form[:message]}
          type="text"
          label="Message"
          autocomplete="off"
          required
          minlength="2"
        />
        <.input
          field={@form[:delay]}
          type="number"
          min="0"
          max="2500"
          step="100"
          label="Echo Delay"
        />
        <footer class="flex justify-end gap-4">
          <.button phx-disable-with="Sending..." variant="primary">
            Send message
            <.icon name="hero-paper-airplane-micro" class="size-4 opacity-75 hover:opacity-100" />
          </.button>
          <.button type="button" phx-click="broadcast">
            Broadcast <.icon name="hero-globe-alt" class="size-4 opacity-75 hover:opacity-100" />
          </.button>
        </footer>
      </.form>

      <div :if={@loading}>
        <.icon name="hero-arrow-path" class="ml-1 size-6 motion-safe:animate-spin" />
      </div>

      <div
        id="chat-messages"
        phx-update="stream"
        class="flex flex-col gap-4"
      >
        <div
          :for={{id, message} <- @streams.messages}
          id={id}
          class="flex flex-col p-4 rounded-box bg-base-200 shadow-md"
        >
          <div class="text-xs font-light">{message.date}</div>
          <div class="font-bold">{message.sender}</div>
          <div class="font-mono">{message.content}</div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("send", params, socket) do
    delay = parse_delay(params["delay"])
    msg = ChatMessage.now(socket.assigns.current_user, params["message"])

    # FIXME: move this to a dedicated genserver
    send(self(), {:new_msg, delay, msg})

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

  defp parse_delay(delay) do
    case Integer.parse(delay) do
      :error ->
        Logger.warning("Error parsing delay from #{inspect(delay)}")
        0

      {n, _} ->
        n
    end
  end

  # FIXME: move this to a dedicated genserver
  @impl true
  def handle_info({:new_msg, delay, %ChatMessage{} = new_msg} = payload, socket) do
    Process.sleep(delay)

    echo_msg = ChatMessage.now("echo.server", "[echo] #{new_msg.content}")

    {:noreply,
     socket
     |> prepend_message(echo_msg)}
  end

  defp prepend_message(socket, new_msg) do
    socket
    |> assign(:loading, false)
    |> stream_insert(:messages, new_msg, at: 0)
  end

  def handle_async(:load_history, {:ok, %{history: messages}} = _payload, socket) do
    socket =
      Enum.reduce(messages, socket, fn msg, sock ->
        stream_insert(sock, :messages, msg, at: -1)
      end)

    {:noreply, assign(socket, :loading, false)}
  end

  defp load_chat_history(current_user) do
    # Simulate slow DB
    Process.sleep(1000)

    history = [
      ChatMessage.now(current_user, "fake history sample msg"),
      ChatMessage.now("echo.server", "[echo] fake history sample msg")
    ]

    %{history: history}
  end
end
