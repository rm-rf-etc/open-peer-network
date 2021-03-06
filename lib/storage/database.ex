defmodule OPN.Database do
  alias OPN.Caylir

  def init(_) do
    conf = Application.fetch_env!(:opn, __MODULE__)
    IO.inspect(conf)
  end

  defp spo(s, p, o), do: %{"subject" => s, "predicate" => p, "object" => o}

  def get_one(subj, pred) do
    case Caylir.query("g.emit(g.V('#{subj}').out('#{pred}').toValue())") do
      [data] -> {:ok, data}
      nil -> {:ok, nil}
      other -> {:error, other}
    end
  end

  def write(s, p, o) when is_binary(s) and is_binary(p) and is_binary(o) do
    "g.emit(g.V('#{s}').out('#{p}').toValue())"
    |> Caylir.query()
    |> object_from_query()
    |> delete_entry(s, p)
    |> write_new(s, p, o)
  end

  defp object_from_query(obj) do
    if is_list(obj), do: Enum.at(obj, 0), else: :none
  end

  defp delete_entry(o, s, p) do
    if is_binary(o), do: Caylir.delete(spo(s, p, o)), else: :ok
  end

  defp write_new(:ok, s, p, o) do
    Caylir.write(spo(s, p, o))
  end

  def collect_garbage(%{:unread_data_ttl => unread_ttl, :absent_user_ttl => absent_ttl}) do
    IO.puts("unread: #{inspect(unread_ttl)}")
    IO.puts("absent: #{inspect(absent_ttl)}")
  end
end
