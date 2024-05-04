defmodule OpenElixirIntelligence.ContextRepo do
  require Logger

  @file_list [
    # "lib/open_elixir_intelligence/open_ei.ex",
    # "lib/open_elixir_intelligence/open_eai.ex",
    # "lib/open_elixir_intelligence/runtime_evaluator.ex",
    # "lib/open_elixir_intelligence/text_extractor.ex",
    "lib/open_elixir_intelligence/very_bad_code.ex",
    "lib/open_elixir_intelligence/divide_by_zero.ex",
    # "lib/open_elixir_intelligence_web/live/open_ei_portal.ex",
    # "lib/open_elixir_intelligence_web/live/open_eai_portal.ex",
    "lib/open_elixir_intelligence/example_system/math.ex"
  ]

  def load_context() do
    @file_list
    |> Enum.map(fn file ->
      case File.read(file) do
        {:ok, contents} ->
          {file, contents}

        {:error, reason} ->
          Logger.warning("Failed to open file #{file}: #{reason}")
          {file, ""}
      end
    end)
    |> Enum.into(%{})
  end

  def find_file_with_error(error_string) do
    @file_list
    |> Enum.find(fn file -> String.contains?(error_string, file) end)
    |> case do
      nil ->
        Logger.warning("No file found in the error message.")
        nil

      file ->
        Logger.info("Found file in error message: #{file}")
        file
    end
  end

  def get_context(file) do
    if file do
      Logger.info("Loading context for source: #{file}")
      context_repo = load_context()
      Map.get(context_repo, file, "No source file in the context repo found\n")
    else
      "No source file in the context repo found\n"
    end
  end
end
