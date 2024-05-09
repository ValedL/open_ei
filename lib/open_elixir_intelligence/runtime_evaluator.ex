defmodule OpenElixirIntelligence.RuntimeEvaluator do
  require Logger
  alias ExUnit.CaptureIO
  alias OpenElixirIntelligence.TextExtractor

  def evaluate(code) do
    # Initialize the agent with an empty map
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    # Capture warnings during code evaluation
    warnings =
      CaptureIO.capture_io(:stderr, fn ->
        try do
          {result, output} = Code.eval_string(TextExtractor.clean_string(code))
          # Store the result in the agent
          Agent.update(agent, fn _ -> %{evaluation: {result, output}, error: ""} end)
        catch
          kind, reason ->
            error = Exception.format(kind, reason, __STACKTRACE__)
            # Store the exception in the agent
            Agent.update(agent, fn _ -> %{evaluation: %{}, error: error} end)
        end
      end)

    # Fetch the stored values
    return_value = Agent.get(agent, fn state -> state end)

    # Construct the final map
    %{
      warnings: warnings,
      evaluation: Map.get(return_value, :evaluation, {}),
      error: Map.get(return_value, :error, "")
    }
  end

  def remove_module_if_present(code_evaluation) do
    # Need to remove the module, otherwise a warning is generated
    # because next run will overwrite the current module
    case code_evaluation do
      {{:module, module_name, _binary, _tuple}, _list} ->
        remove_module(module_name)

      _ ->
        Logger.info("No module defined in the code.")
    end
  end

  def remove_module(module_name) do
    try do
      :code.purge(module_name)
      :code.delete(module_name)
    rescue
      _ -> :ok
    end
  end

  def apply_hotreload_fix(source_code) do
    clean_source_code = OpenElixirIntelligence.TextExtractor.clean_string(source_code)
    {result, _output} = Code.eval_string(clean_source_code)

    case result do
      {{:module, module_name, _binary, _tuple}, _list} ->
        case Code.compile_string(clean_source_code, to_string(module_name)) do
          [{_module, module_binary}] ->
            reload_code(module_name, module_binary)
            OpenElixirIntelligence.ContextRepo.save_updated_code(module_name, clean_source_code)

          _ ->
            Logger.error("Failed to compile the module: #{inspect(module_name)}")
        end

      {:module, module_name, _binary, _tuple} ->
        case Code.compile_string(clean_source_code, to_string(module_name)) do
          [{_module, module_binary}] ->
            reload_code(module_name, module_binary)
            OpenElixirIntelligence.ContextRepo.save_updated_code(module_name, clean_source_code)

          _ ->
            Logger.error("Failed to compile the module: #{inspect(module_name)}")
        end

      _ ->
        Logger.error("No module defined in the source code.")
    end
  end

  defp reload_code(module_name, module_binary) do
    case :code.purge(module_name) do
      true ->
        :code.load_binary(module_name, ~c"nofile", module_binary)

      false ->
        Logger.warning(
          "Failed to purge the old version of #{module_name}. Trying to delete and load again."
        )

        try do
          :code.delete(module_name)
          :code.load_binary(module_name, ~c"nofile", module_binary)
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
        end
    end
  end

  def evaluate_and_construct_message(code, example, output) do
    intro_message = """
    I have evaluated your code by executing it in runtime environment via Code.eval_string. \n
    """

    {code_evaluation_message, code_evaluation} = evaluate_code(code)
    example_evaluation_message = evaluate_example(example, output)
    remove_module_if_present(code_evaluation)
    intro_message <> code_evaluation_message <> example_evaluation_message
  end

  defp evaluate_code(code) do
    %{error: code_errors, warnings: code_warnings, evaluation: code_evaluation} =
      evaluate(TextExtractor.clean_string(code))

    code_evaluation_message =
      if code_errors != "" or code_warnings != "" do
        "Code compilation errors: \n" <>
          code_errors <>
          "\n" <>
          "Code compilation warnings: \n" <> code_warnings <> "\n"
      else
        "Code evaluation completed without errors and warnings!\n"
      end

    {code_evaluation_message, code_evaluation}
  end

  defp evaluate_example(example, output) do
    %{error: example_errors, warnings: example_warnings, evaluation: example_evaluation} =
      evaluate(TextExtractor.clean_string(example))

    example_evaluation_message =
      if example_errors != "" or example_warnings != "" do
        "Example compilation errors: \n" <>
          example_errors <>
          "\n" <>
          "Example compilation warnings: \n" <> example_warnings <> "\n"
      else
        "Example evaluation completed without errors and warnings! Excellent!\n"
      end

    example_evaluation_message =
      example_evaluation_message <>
        "Execution output of example code is, as provided by Code.eval_string: \n" <>
        "#{inspect(example_evaluation)}" <>
        "\n" <>
        "vs the expected result: " <> output <> "\n"

    example_evaluation_message
  end

  def get_runtime_data() do
    top = Runtime.top()
    pid = hd(Runtime.top()).pid
    info = Process.info(pid, :current_stacktrace)
    trace = Runtime.trace(pid)

    runtime_data_string =
      "Top PIDs by CPU usage: #{inspect(top)}" <>
        "Stacktrace of processes with highest CPU usage: #{inspect(info)}\n" <>
        "Trace of the process with the hughest CPU usage:  #{inspect(trace)}\n"

    runtime_data_string
  end

  def monitor_cpu_usage() do
    Logger.warning("Spinning up task to monitor CPU usage.")

    Task.start(fn ->
      Process.flag(:priority, :max)
      loop()
    end)
  end

  defp loop() do
    t0_top_process = hd(Runtime.top())
    # Sleep for 3 seconds
    Process.sleep(3000)
    t3_top_process = hd(Runtime.top())

    if t0_top_process.pid == t3_top_process.pid and
         t0_top_process.cpu >= 95 and t3_top_process.cpu >= 95 do
      Logger.info("Process #{inspect(t0_top_process.pid)} is consuming high CPU for 3 seconds.")
      message = "Process #{inspect(t0_top_process.pid)} is consuming high CPU."
      stacktrace = get_stacktrace(t0_top_process.pid)
      trace = get_trace(t0_top_process.pid)
      Logger.error(message <> "\n" <> stacktrace <> "\n" <> trace)
    else
      loop()
    end
  end

  def get_stacktrace(pid) do
    stacktrace = Process.info(pid, :current_stacktrace)
    "#{inspect(stacktrace)}"
  end

  def get_trace(pid) do
    trace =
      Runtime.trace(pid)
      |> Enum.take(10)

    "#{inspect(trace)}"
  end
end
