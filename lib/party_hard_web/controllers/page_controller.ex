defmodule PartyHardWeb.PageController do
  use PartyHardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
