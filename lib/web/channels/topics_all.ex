defmodule OPNWeb.TopicAll do
  use Phoenix.Channel
  # use Guardian, otp_app: :opn
  alias OPN.Database
  alias OPNWeb.Endpoint

  # Temporary hardcoded secret key to use until NaCl is setup
  @secret_key "48EkqJIWdB4bWoNznv9sNC3wagcoqAvQTSQjmTtyjtc="
  @public_key "GFEwAov/WzRS+Dmq3KUtScROZ8oEeh+mkAtWMYY41xY="

  @moduledoc """
  In our architecture, each ID is a topic.

      {
        "user_id1": {
          "firstName": "Rob"
        }
      }

  Would be topic `user_id1:firstName`, with a message payload of
  `{ "data": "Rob" }`
  """

  defp nonce() do
    :binary.list_to_bin(for _ <- 1..24, do: Enum.random(0..255))
  end

  defp encrypt(socket, data) do
    Kcl.box(
      Jason.encode!(data),
      nonce(),
      Base.decode64!(@secret_key),
      Base.decode64!(socket.assigns["public_key"])
    )
  end

  defp decrypt(socket, box, nonce) do
    {json, _state} =
      Kcl.unbox(
        Base.decode64!(box),
        Base.decode64!(nonce),
        Base.decode64!(@secret_key),
        Base.decode64!(socket.assigns["public_key"])
      )

    json
  end

  def init(state), do: {:ok, state}

  def join(_topics, payload, socket) do
    case payload do
      %{"public_key" => public_key} ->
        send(self(), :new_connection)
        {:ok, Phoenix.Socket.assign(socket, %{"public_key" => public_key})}

      _ ->
        {:error, "connection requests must include your public_key"}
    end
  end

  def handle_info(:new_connection, socket) do
    push(socket, "connect", %{"public_key" => @public_key})
    {:noreply, socket}
  end

  def handle_in("read:" <> req_id, %{"box" => box, "nonce" => nonce}, socket) do
    query_map = Jason.decode!(decrypt(socket, box, nonce))

    case Database.query(query_map) do
      {:ok, data} ->
        {msg, state} = encrypt(socket, data)

        push(socket, "read:#{req_id}", %{
          "box" => Base.encode64(msg),
          "nonce" => Base.encode64(state.previous_nonce)
        })

        {:noreply, socket}

      {:error, reason} ->
        push(socket, "read:#{req_id}", %{"error" => reason})
        IO.puts("query failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_in("write", %{"box" => box, "nonce" => nonce}, socket) do
    case Jason.decode(decrypt(socket, box, nonce)) do
      {:ok, %{"s" => s, "p" => p, "o" => o}}
      when is_binary(s) and is_binary(p) and is_binary(o) ->
        # DeltaCrdt.mutate(crdt, :add, ["#{s}:#{p}", o])
        resp = Database.write(s, p, o)
        IO.puts("write: #{inspect(resp)}")

        resp = Endpoint.broadcast!("#{s}:#{p}", "value", %{"data" => o})
        IO.puts("broadcast returned: #{inspect(resp)}")

        {:noreply, socket}

      json ->
        IO.puts("JSON decode failed: #{inspect(json)}")
        {:noreply, socket}
    end
  end

  def handle_in("vault:" <> req_id, %{"s" => subj, "p" => pred, "password" => pw_stated}, socket) do
    #
    # Implement Guardian here
    #
    case Database.query(%{"s" => subj, "p" => pred}) do
      %{"data" => %{"password" => pw_found}} ->
        if pw_found == pw_stated do
          #
          # NOT A REAL IMPLEMENTATION
          #
          push(socket, "vault:#{req_id}", %{"status" => "success"})
        else
          push(socket, "vault:#{req_id}", %{"status" => "denied"})
        end

        {:noreply, socket}

      _ ->
        push(socket, "vault:#{req_id}", %{"status" => "error", "code" => 500})
        {:noreply, socket}
    end
  end

  def handle_in(action, payload, socket) do
    IO.puts("No match for action: #{inspect(action)}, payload: #{inspect(payload)}")
    {:noreply, socket}
  end
end