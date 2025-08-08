defmodule PartyHardWeb.Router do
  use PartyHardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PartyHardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_user_token
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PartyHardWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", LiveChat.Index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PartyHardWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:party_hard, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PartyHardWeb.Telemetry
    end
  end

  # extra stuff
  # FIXME: add a nice docker-like random names
  defp put_user_token(conn, _) do
    current_user =
      case get_session(conn, :current_user) do
        nil -> "user-#{:rand.uniform(999)}-#{:rand.uniform(999)}"
        u -> u
      end

    conn
    |> assign(:current_user, current_user)
    |> put_session(:current_user, current_user)
  end
end
