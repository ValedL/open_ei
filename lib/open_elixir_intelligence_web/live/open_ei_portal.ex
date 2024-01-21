defmodule OpenElixirIntelligenceWeb.OpenEIPortal do
  use OpenElixirIntelligenceWeb, :live_view

  require Logger

  alias OpenElixirIntelligence
  alias OpenElixirIntelligence.PubSub
  alias OpenElixirIntelligence.OpenEI

  def mount(_params, _session, socket) do
    socket = assign(socket, form: to_form(%{}, as: "object"))
    Phoenix.PubSub.subscribe(PubSub, OpenEI.topic_response_stream())
    Phoenix.PubSub.subscribe(PubSub, OpenEI.topic_user_message())
    Phoenix.PubSub.subscribe(PubSub, OpenEI.topic_successfull_solution())
    message = OpenEI.get_raw_messages()

    {:ok, assign(socket, text: nil, content: "", cancel?: false, raw_messages: message)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <img src="/images/Logo_Concept_2.png" class="h-1/8 w-1/8" />
      <div class="font-bold text-5xl">Elixir Intelligence</div>
      <div class="w-full mx-auto">
        <%= for %{role: role, content: content} <- @raw_messages do %>
          <.card class="mt-4">
            <.card_content
              category={role}
              class={"max-w-full #{if role == "user", do: "bg-gray-600 bg-opacity-60", else: "bg-blue-600 bg-opacity-20"}"}
            >
              <div class="whitespace-pre-line">
                <%= content %>
              </div>
            </.card_content>
          </.card>
        <% end %>
        <div class="mb-20"></div>
      </div>

      <div
        class="w-full bg-white dark:bg-gray-800 shadow p-4"
        style="background: rgba(255, 255, 255, 0.6);"
      >
        <form phx-submit="submit_text" class="w-full">
          <textarea
            name="text"
            id="message"
            rows="4"
            class="mt-4 block p-2.5 w-full text-sm text-gray-900 bg-gray-50 rounded-lg border border-gray-300 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
            placeholder="Write your thoughts here..."
          ><%= assigns.text %></textarea> <br />
          <div class="flex flex-row justify-center">
            <.button :if={not @cancel?} class="m-4 z-50" type="submit" color="success">
              Submit
            </.button>
            <.button
              :if={@cancel?}
              color="danger"
              label="Cancel"
              variant="shadow"
              phx-click="cancel_generation"
              class="m-4 z-5"
            />
            <.button
              color="info"
              label="New Chat"
              variant="shadow"
              phx-click="new_chat"
              class="m-4 z-50"
            />
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_info({:new_response, _}, socket) do
    message = socket.assigns.raw_messages ++ [%{role: "assistant", content: ""}]
    {:noreply, assign(socket, cancel?: true, raw_messages: message)}
  end

  def handle_info({:new_content, new_content}, socket) do
    raw_messages = socket.assigns.raw_messages
    last_index = length(raw_messages) - 1

    updated_raw_messages =
      List.update_at(raw_messages, last_index, fn last_message ->
        Map.update!(last_message, :content, &(&1 <> new_content))
      end)

    {:noreply, assign(socket, raw_messages: updated_raw_messages)}
  end

  def handle_info({:user_message, message}, socket) do
    Logger.info("User message: #{inspect(message)}")
    message = socket.assigns.raw_messages ++ [%{role: "user", content: message}]
    {:noreply, assign(socket, raw_messages: message)}
  end

  def handle_info({:successfull_solution, message}, socket) do
    {:noreply, assign(socket, cancel?: false)}
  end

  def handle_event("submit_text", %{"text" => text}, socket) do
    Phoenix.PubSub.local_broadcast(PubSub, OpenEI.topic_user_message(), {:user_message, text})
    {:noreply, socket}
  end

  def handle_event("new_chat", _params, socket) do
    OpenEI.reset_state()
    message = OpenEI.get_raw_messages()
    {:noreply, assign(socket, content: "", cancel?: false, raw_messages: message)}
  end

  def handle_event("cancel_generation", _params, socket) do
    OpenEI.cancel_generation()
    {:noreply, socket}
  end
end
