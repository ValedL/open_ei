defmodule OpenElixirIntelligenceWeb.ExampleSystemWeb.Load.Dashboard do
  use OpenElixirIntelligenceWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       load: changeset(LoadControl.load()),
       schedulers: changeset(:erlang.system_info(:schedulers_online)),
       metrics: ExampleSystem.Metrics.subscribe(),
       highlighted: nil
     )}
  end

  # @impl Phoenix.LiveView
  # def render(assigns), do: ExampleSystemWeb.Load.View.render("dashboard.html", assigns)

  @impl Phoenix.LiveView
  def handle_event("change_load", %{"data" => %{"value" => load}}, socket) do
    with {load, ""} when load >= 0 <- Integer.parse(load) do
      Task.start_link(fn -> LoadControl.change_load(load) end)
      {:noreply, assign(socket, :load, changeset(load))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("change_schedulers", %{"data" => %{"value" => schedulers}}, socket) do
    with {schedulers, ""} when schedulers > 0 <- Integer.parse(schedulers) do
      Task.start_link(fn -> LoadControl.change_schedulers(schedulers) end)
      {:noreply, assign(socket, :schedulers, changeset(schedulers))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("reset", _params, socket) do
    me = self()

    Task.start_link(fn ->
      ExampleSystem.Metrics.subscribe()

      LoadControl.change_load(0)

      fn -> ExampleSystem.Metrics.await_next() end
      |> Stream.repeatedly()
      |> Stream.drop_while(&(&1.jobs_rate > 0))
      |> Enum.take(1)

      LoadControl.change_schedulers(1)
      Process.sleep(1000)

      send(me, :clear_history)
    end)

    {:noreply, socket}
  end

  def handle_event("highlight_" <> what, _params, socket) do
    highlighted = if socket.assigns.highlighted == what, do: nil, else: what
    {:noreply, assign(socket, :highlighted, highlighted)}
  end

  def handle_info({:metrics, metrics}, socket), do: {:noreply, assign(socket, :metrics, metrics)}

  def handle_info({:metrics, metrics}, socket) when is_map(metrics) do
    {:noreply, assign(socket, :metrics, metrics)}
  end

  def handle_info(:clear_history, socket) do
    ExampleSystem.Metrics.clear_history()

    {:noreply,
     assign(socket,
       load: changeset(LoadControl.load()),
       schedulers: changeset(:erlang.system_info(:schedulers_online))
     )}
  end

  defp changeset(value),
    do: Ecto.Changeset.cast({%{}, %{value: :integer}}, %{value: value}, [:value])

  def highlight_class(a, a), do: "highlight"
  def highlight_class(_, _), do: ""

  def data_points(graph) do
    graph.data_points
    |> Stream.map(&"#{x(&1.x)},#{y(&1.y)}")
    |> Enum.join(" ")
  end

  def x(relative_x), do: min(round(relative_x * graph_width()), graph_width())
  def y(relative_y), do: graph_height() - min(round(relative_y * graph_height()), graph_height())

  def graph_width(), do: 150
  def graph_height(), do: 150
end
