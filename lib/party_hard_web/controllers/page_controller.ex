defmodule PartyHardWeb.PageController do
  use PartyHardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def signoff(conn, _params) do
    conn
    |> delete_session(:current_user)
    |> redirect(to: ~p"/chat")
  end
end
