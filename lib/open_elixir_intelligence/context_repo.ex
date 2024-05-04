defmodule OpenElixirIntelligence.ContextRepo do
  require Logger

  @file_list Path.wildcard("lib/**/*.ex")

  def get_file_list do
    @file_list
  end

  def extract_module_names(file_list) do
    Enum.into(file_list, %{}, fn file ->
      module_name =
        file
        |> String.replace("lib/", "")
        |> String.replace(".ex", "")
        |> String.split("/")
        |> Enum.map(fn path_part ->
          path_part
          |> String.split("_")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join("")
        end)
        |> Enum.join(".")

      {module_name, file}
    end)
  end

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

  def get_module_file_pairs do
    :code.all_loaded()
    |> Enum.map(fn {module, file} -> {Atom.to_string(module), file} end)
  end

  def find_file_with_error(error_string) do
    file =
      @file_list
      |> Enum.find(fn file -> String.contains?(error_string, file) end)

    if is_nil(file) do
      Logger.warning("No file found in the error message.")
      module_file_pairs = extract_module_names(@file_list)

      module_name =
        Map.keys(module_file_pairs)
        |> Enum.find(fn module -> String.contains?(error_string, module) end)

      if is_nil(module_name) do
        Logger.warning("No module found in the error message.")
        nil
      else
        Logger.info("Found module in error message: #{module_name}")
        Map.get(module_file_pairs, module_name)
      end
    else
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
