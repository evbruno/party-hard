defmodule PartyHard.EchoServer.Message do
  @moduledoc """
  Represents a message in the echo server.
  """
  @type t :: %__MODULE__{
          id: integer(),
          date: NaiveDateTime.t(),
          content: String.t(),
          sender: String.t(),
          broadcast: boolean()
        }
  defstruct id: -1, date: "", content: "", sender: "", broadcast: false

  @spec now(sender :: String.t(), content :: String.t(), delta :: integer()) :: t()
  def now(sender, content, delta \\ 0) do
    %__MODULE__{
      id: System.unique_integer([:monotonic, :positive]),
      date: NaiveDateTime.utc_now() |> NaiveDateTime.add(delta),
      content: content,
      sender: sender
    }
  end
end
