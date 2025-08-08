defmodule PartyHard.EchoServer.Message do
  defstruct id: -1, date: "", content: "", sender: "", broadcast: false

  def now(sender, content, delta \\ 0) do
    %__MODULE__{
      id: System.unique_integer([:monotonic, :positive]),
      date: NaiveDateTime.utc_now() |> NaiveDateTime.add(delta),
      content: content,
      sender: sender
    }
  end
end

defmodule PartyHard.EchoServer.History do
  defstruct user: nil, messages: []

  def prepend(state, new_msg) do
    %__MODULE__{
      state
      | messages: [new_msg | state.messages]
    }
  end
end

defmodule PartyHard.EchoServer do
  use GenServer
  require Logger
  alias PartyHard.EchoServer.History
  alias PartyHard.EchoServer.Message

  # ---  public apis ---

  # @spec load_history(user :: String.t()) :: History.t()
  def load_history(user),
    do: lookup_or_spawn(user) |> GenServer.call(:load_history)

  def echo_message(user, message, delay \\ 0),
    do: lookup_or_spawn(user) |> GenServer.call({:echo, user, message, delay})

  def start_link(user) do
    GenServer.start_link(__MODULE__, user, name: via_tuple(user))
  end

  # --- callbacks ---

  @impl true
  def init(user) do
    Logger.info("#{__MODULE__}: init #{user}")
    {:ok, %History{user: user}}
  end

  # @impl true
  # def handle_call(:inc, _from, {user, count} = b) do
  #   IO.puts("handle_call :inc  =? #{inspect(b)}")
  #   {:reply, count, {user, count + 1}}
  # end

  # @impl true
  # def handle_call(:get, _from, {_user, count} = state) do
  #   {:reply, count, state}
  # end

  @impl true
  def handle_call(:load_history, _from, %History{} = state) do
    IO.puts("handle_call load_history => #{inspect(state)}")
    {:reply, state, state}
  end

  @impl true
  def handle_call({:echo, sender, msg, delay} = params, {from_pid, _}, %History{} = state) do
    IO.puts("handle_cast echo => #{inspect(params)} => #{inspect(state)}")
    new_msg = Message.now(sender, msg)
    state = History.prepend(state, new_msg)

    Process.send_after(self(), {:echo_proc, from_pid, new_msg}, delay)

    {:reply, new_msg, state}
  end

  @impl true
  def handle_info({:echo_proc, from_pid, %Message{} = msg}, state) do
    IO.puts("handle_info echo_proc from_pid => #{is_pid(from_pid)}? #{inspect(from_pid)}")
    IO.puts("handle_info echo_proc msg => #{inspect(msg)}")

    new_msg = Message.now("server.echo", "[e] #{msg.content}")
    state = History.prepend(state, new_msg)

    send(from_pid, {:echo_reply, new_msg})

    {:noreply, state}
  end

  # --- helpers ---

  defp lookup_or_spawn(user) do
    case Registry.lookup(PartyHard.EchoServerRegistry, user) do
      [{pid, _}] ->
        Logger.info("#{__MODULE__} spec #{user} found #{inspect(pid)}")
        pid

      _ ->
        Logger.info("#{__MODULE__} spec #{user} NOT FOUND.. creating a new one")

        spec = %{
          id: PartyHard.EchoServer,
          start: {PartyHard.EchoServer, :start_link, [user]},
          restart: :transient,
          type: :worker
        }

        {:ok, pid} = DynamicSupervisor.start_child(PartyHard.EchoServerSupervisor, spec)
        pid
    end
  end

  defp via_tuple(user) do
    {:via, Registry, {PartyHard.EchoServerRegistry, user}}
  end
end
