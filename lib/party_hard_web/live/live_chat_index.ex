defmodule PartyHardWeb.LiveChat.Index do
  use PartyHardWeb, :live_view
  require Logger

  alias PartyHard.EchoServer.Message, as: ChatMessage
  # alias PartyHard.EchoServer.History, as: ChatHistory
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Welcome <span class="text-2xl font-extrabold
        subpixel-antialiased
    ">{@current_user}</span>
        <:subtitle>This is a echo server (in memory history)</:subtitle>
      </.header>

      <.form id="message-form" for={@form} phx-submit="send" phx-change="update_delay">
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
          type="range"
          min="0"
          max="3000"
          step="250"
          label="Echo Delay"
        />
        <footer class="text-xs mt-2 mb-3 label mb-1">
          (millis) {@form.params["delay"]}
        </footer>
        <footer class="flex justify-end gap-4">
          <.button phx-disable-with="Sending..." variant="primary">
            Send message
            <.icon name="hero-paper-airplane-micro" class="size-4 opacity-75 hover:opacity-100" />
          </.button>
          <.button type="button" phx-click="broadcast">
            Broadcast <.icon name="hero-globe-alt" class="size-4 opacity-75 hover:opacity-100" />
          </.button>
          <.button type="button" phx-click="signout">
            Signout
            <.icon
              name="hero-arrow-left-start-on-rectangle"
              class="size-4 opacity-75 hover:opacity-100"
            />
          </.button>
        </footer>
      </.form>

      <div :if={@loading?}>
        <.icon name="hero-loading" class="ml-1 size-6 motion-safe:animate-spin" />
      </div>

      <div
        :if={@empty? and not @loading?}
        class="flex py-3 justify-center text-sm text-base-content/70 subpixel-antialiased font-mono"
      >
        <p>
          empty history <.icon name="hero-warning" class="ml-1 size-4 hero-exclamation-triangle" />
        </p>
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
