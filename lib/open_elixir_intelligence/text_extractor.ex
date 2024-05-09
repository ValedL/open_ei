defmodule OpenElixirIntelligence.TextExtractor do
  require Logger

  def extract(text) do
    %{
      "#CODE" => extract_between_tags(text, "#CODE"),
      "#EXAMPLE" => extract_between_tags(text, "#EXAMPLE"),
      "#OUTPUT" => extract_between_tags(text, "#OUTPUT")
    }
  end

  def extract_for_fix(text) do
    %{
      "#SOURCE" => extract_between_tags(text, "#SOURCE"),
      "#LINE" => extract_between_tags(text, "#LINE"),
      "#DESCRIPTION" => extract_between_tags(text, "#DESCRIPTION"),
      "#TIMESTAMP" => extract_between_tags(text, "#TIMESTAMP"),
      "#POSSIBLE_ISSUES" => extract_between_tags(text, "#POSSIBLE_ISSUES"),
      "#POSSIBLE_SOLUTIONS" => extract_between_tags(text, "#POSSIBLE_SOLUTIONS"),
      "#BEST_SOLUTION" => extract_between_tags(text, "#BEST_SOLUTION"),
      "#TEST" => extract_between_tags(text, "#TEST")
    }
  end

  def extract_solution(text) do
    %{
      "#SOLUTION_SUCCESS" => extract_between_tags(text, "#SOLUTION_SUCCESS"),
      "#WORKING_CODE" => extract_between_tags(text, "#WORKING_CODE"),
      "#DESCRIPTION" => extract_between_tags(text, "#DESCRIPTION")
    }
  end

  def extract_fix(text) do
    %{
      "#FIXED_SOURCE_CODE" => extract_between_tags(text, "#FIXED_SOURCE_CODE")
    }
  end

  def extract_state(text) do
    state = extract_between_tags(text, "#STATE")
    Logger.info("Extracted state: #{state}")
    state
  end

  def extract_between_tags(text, tag) do
    if String.contains?(text, tag) do
      parts = String.split(text, tag) |> Enum.reverse()
      prev_content = Enum.at(parts, 1)

      if prev_content do
        clean_string(prev_content)
      else
        ""
      end
    else
      ""
    end
  end

  def clean_string(content) do
    content
    |> String.replace("```elixir", "")
    |> String.replace("```", "")
    |> String.trim()
  end
end
