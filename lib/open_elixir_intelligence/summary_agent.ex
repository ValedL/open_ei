defmodule OpenElixirIntelligence.SummaryAgent do
  use GenServer
  require Logger
  alias OpenaiEx.ChatCompletion

  @topic_user_message "summary_agent:user_message"
  @topic_response_stream "summary_agent:response_stream"

  def topic_user_message, do: @topic_user_message
  def topic_response_stream, do: @topic_response_stream

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(OpenElixirIntelligence.PubSub, topic_user_message())
    {:ok, load_openai_config()}
  end

  defp load_openai_config() do
    apikey = System.fetch_env!("OPENAI_API_KEY")
    openai = OpenaiEx.new(apikey)
    model_type = System.get_env("OPENAI_MODEL_TYPE", "gpt-4")

    system_prompt =
      System.get_env(
        "OPENAI_SYSTEM_PROMPT",
        """
        You are monitoring a multi-agent system that tries to fix software issues.
        Every message received desribes what the agent is doing or suggesting to do.
        Summarize each message as supershort bullet point, that desciptes the gist of the action.

        Example:

        User:
          #SOURCE
          lib/fluffy_train/divide_by_zero.ex
          #SOURCE

          #LINE
          6
          #LINE

          #DESCRIPTION
          The error is an ArithmeticError indicating that there was an invalid argument in an arithmetic expression, probably a division by zero. This error occurs within the Task process started from OpenElixirIntelligence.VeryBadCode.
          #DESCRIPTION

          #TIMESTAMP
          October 29, 2023 19:38:52.574 GMT
          #TIMESTAMP

        Assistant:
          Caught the ArithmeticError in lib/fluffy_train/divide_by_zero.ex:6

        User:
          #WORKING_CODE
          defmodule LlmEvaluator.OpenElixirIntelligence.DivideByZero do
          def execute() do
          number = 10
          divisor = 0
          IO.puts("Attempting to divide by zero...")

          try do
          result = number / divisor
          IO.puts("Result: {result}")
          rescue
          ArithmeticError ->
          IO.puts("Cannot divide by zero")
          end
          end
          end
          #WORKING_CODE

          #DESCRIPTION
          This solution uses a try/rescue block to catch this error and print a friendly message to the console
          instead of crashing the program. The division operation is wrapped in the try block,
          and if an ArithmeticError occurs, it is caught in the rescue block. In the rescue block,
          we simply print out a message stating that "Cannot divide by zero" to give a meaningful output.

        Assistant:
          Added a try/rescue block to catch the ArithmeticError in lib/fluffy_train/divide_by_zero.ex:6
        """
      )

    %{
      openai: openai,
      model_type: model_type,
      system_prompt: system_prompt
    }
  end

  def summarize(text, from \\ "N/A") do
    Phoenix.PubSub.broadcast(
      OpenElixirIntelligence.PubSub,
      OpenElixirIntelligence.SummaryAgent.topic_user_message(),
      {:user_message, text, from}
    )
  end

  def handle_info({:user_message, message, from}, state) do
    # Logger.info("Received user message: #{inspect(message)}")

    Task.start(fn ->
      response = get_openai_response(state, message)

      Phoenix.PubSub.local_broadcast(
        OpenElixirIntelligence.PubSub,
        topic_response_stream(),
        {:new_response, ""}
      )

      Enum.each(response, fn content ->
        Phoenix.PubSub.local_broadcast(
          OpenElixirIntelligence.PubSub,
          topic_response_stream(),
          {:new_content, content}
        )
      end)

      final_response = Enum.join(response, "")

      Logger.warning("Final response: #{inspect(final_response)}")

      Phoenix.PubSub.local_broadcast(
        OpenElixirIntelligence.PubSub,
        topic_response_stream(),
        {:final_response, final_response, from}
      )
    end)

    {:noreply, state}
  end

  defp get_openai_response(state, user_message) do
    completion_request = create_completion_request(state, user_message)
    completion_stream = state.openai |> ChatCompletion.create(completion_request, stream: true)

    completion_stream
    |> Stream.flat_map(& &1)
    |> Stream.map(fn %{data: d} ->
      d |> Map.get("choices") |> Enum.at(0) |> Map.get("delta")
    end)
    |> Stream.filter(fn map -> map |> Map.has_key?("content") end)
    |> Stream.map(fn map -> map |> Map.get("content") end)
    |> Enum.to_list()
  end

  defp create_completion_request(state, user_message) do
    messages =
      [
        %{role: "system", content: state.system_prompt},
        %{role: "user", content: user_message}
      ]

    ChatCompletion.new(model: state.model_type, messages: messages)
  end
end
