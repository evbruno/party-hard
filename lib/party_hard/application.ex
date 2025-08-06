defmodule PartyHard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PartyHardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:party_hard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PartyHard.PubSub},
      # Start a worker by calling: PartyHard.Worker.start_link(arg)
      # {PartyHard.Worker, arg},
      # Start to serve requests, typically the last entry
      PartyHardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PartyHard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PartyHardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
