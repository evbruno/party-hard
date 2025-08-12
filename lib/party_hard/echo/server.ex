defmodule PartyHard.EchoServer do
  @moduledoc """
  Echo server implementation.  Handles message echoing and history tracking for users.
  """

  use GenServer
  require Logger
  alias PartyHard.EchoServer.History
  alias PartyHard.EchoServer.Message

  # ---  public apis ---
  #

  @spec broadcast_message(sender :: String.t(), msg :: String.t()) ::
          {:ok, Message.t()}
  def broadcast_message(user, msg),
    do: lookup_or_spawn(user) |> GenServer.call({:local, user, msg})

  @spec load_history(user :: String.t()) :: History.t()
  def load_history(user),
    do: lookup_or_spawn(user) |> GenServer.call(:load_history)

  @spec echo_message(user :: String.t(), message :: String.t(), delay :: non_neg_integer()) ::
          Message.t()
  def echo_message(user, message, delay \\ 0),
    do: lookup_or_spawn(user) |> GenServer.call({:echo, user, message, delay})

  @spec add_to_history(user :: String.t(), msg :: Message.t()) :: History.t()
  def add_to_history(user, msg),
    do: lookup_or_spawn(user) |> GenServer.call({:add_to_history, msg})

  @spec start_link(user :: String.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(user) do
    GenServer.start_link(__MODULE__, user, name: via_tuple(user))
  end

  # --- callbacks ---

  @impl true
  def init(user) do
    Logger.info("#{__MODULE__}: init #{user}")
    {:ok, %History{user: user}}
  end

  @impl true
  def handle_call({:add_to_history, new_msg}, _from, %History{} = state) do
    state = History.prepend(state, new_msg)

    {:reply, state, state}
  end

  @impl true
  def handle_call(:load_history, _from, %History{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:local, sender, msg}, _, %History{} = state) do
    new_msg = Message.now(sender, msg, true)
    state = History.prepend(state, new_msg)

    {:reply, new_msg, state}
  end

  @impl true
  def handle_call({:echo, sender, msg, delay} = _params, {from_pid, _}, %History{} = state) do
    new_msg = Message.now(sender, msg, false)
    state = History.prepend(state, new_msg)

    Process.send_after(self(), {:echo_proc, from_pid, new_msg}, delay)

    {:reply, new_msg, state}
  end

  @impl true
  def handle_info({:echo_proc, from_pid, %Message{} = msg}, state) do
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
