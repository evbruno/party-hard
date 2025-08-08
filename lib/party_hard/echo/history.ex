defmodule PartyHard.EchoServer.History do
  @moduledoc """
  Represents the message history for a user in the echo server.
  """
  @type t :: %__MODULE__{user: String.t(), messages: list(PartyHard.EchoServer.Message.t())}
  defstruct user: nil, messages: []

  @spec prepend(t(), PartyHard.EchoServer.Message.t()) :: t()
  def prepend(state, new_msg) do
    %__MODULE__{
      state
      | messages: [new_msg | state.messages]
    }
  end
end
