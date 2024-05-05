defmodule OpenElixirIntelligence.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    LoadControl.change_schedulers(1)

    children = [
      OpenElixirIntelligence.ContextRepo,
      # Start the Telemetry supervisor
      OpenElixirIntelligenceWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: OpenElixirIntelligence.PubSub},
      # Start Finch
      {Finch, name: OpenElixirIntelligence.Finch},
      # Start the Endpoint (http/https)
      OpenElixirIntelligenceWeb.Endpoint,
      OpenElixirIntelligence.OpenEI,
      OpenElixirIntelligence.OpenEAI,
      OpenElixirIntelligence.SummaryAgent,
      OpenElixirIntelligence.VeryBadCode,
      ExUnit.Server,
      ExUnit.CaptureServer,
      OpenElixirIntelligence.ExampleSystem.Math,
      ExampleSystem.Metrics,
      ExampleSystem.Service,
      ExampleSystem.Top
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenElixirIntelligence.Supervisor]

    with {:ok, pid} <-
           Supervisor.start_link(children, opts) do
      LoadControl.change_load(0)

      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OpenElixirIntelligenceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
