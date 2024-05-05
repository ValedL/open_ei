defmodule OpenElixirIntelligenceWeb.ExampleSystemWeb.Math.Sum do
  use OpenElixirIntelligenceWeb, :live_view
  alias OpenElixirIntelligence.ExampleSystem
  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    Logger.info("ExampleSystemWeb.Math.Sum mount")
    {:ok, assign(socket, operations: [], data: data())}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", %{"data" => %{"to" => str_input}}, socket),
    do: {:noreply, start_sum(socket, str_input)}

  @impl Phoenix.LiveView
  def handle_info({:sum, pid, sum}, socket),
    do: {:noreply, update(socket, :operations, &set_result(&1, pid, sum))}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, socket),
    do: {:noreply, update(socket, :operations, &set_result(&1, pid, :error))}

  defp start_sum(socket, str_input) do
    operation =
      case Integer.parse(str_input) do
        :error ->
          %{pid: nil, input: str_input, result: "invalid input"}

        {_input, remaining} when byte_size(remaining) > 0 ->
          %{pid: nil, input: str_input, result: "invalid input"}

        # {input, ""} when input <= 0 -> %{pid: nil, input: input, result: "invalid input"}
        {input, ""} ->
          do_start_sum(input)
      end

    socket |> update(:operations, &[operation | &1]) |> assign(:data, data())
  end

  defp do_start_sum(input) do
    case ExampleSystem.Math.sum(input) do
      {:ok, pid} ->
        %{pid: pid, input: input, result: :calculating}

      {:error, reason} ->
        %{pid: nil, input: input, result: reason}
    end
  end

  defp set_result(operations, pid, result) do
    case Enum.split_with(operations, &match?(%{pid: ^pid, result: :calculating}, &1)) do
      {[operation], rest} -> [%{operation | result: result} | rest]
      _other -> operations
    end
  end

  defp data(), do: Ecto.Changeset.cast({%{}, %{to: :integer}}, %{to: ""}, [:to])
end
