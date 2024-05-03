defmodule OpenElixirIntelligence.ContextRepo do
  require Logger

  @file_list [
    "lib/open_elixir_intelligence/open_ei.ex",
    "lib/open_elixir_intelligence/open_eai.ex",
    "lib/open_elixir_intelligence/runtime_evaluator.ex",
    "lib/open_elixir_intelligence/text_extractor.ex",
    "lib/open_elixir_intelligence/very_bad_code.ex",
    "lib/open_elixir_intelligence/divide_by_zero.ex",
    "lib/open_elixir_intelligence_web/live/open_ei_portal.ex",
    "lib/open_elixir_intelligence_web/live/open_eai_portal.ex"
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
end
