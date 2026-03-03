defmodule ChatApi.Store do
  @moduledoc """
  In-memory ETS store for users and messages. No database.
  """
  use GenServer

  @users_table :chat_api_users
  @messages_table :chat_api_messages
  @read_receipts_table :chat_api_read_receipts
  @seq_table :chat_api_conversation_seqs

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@users_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@messages_table, [:named_table, :ordered_set, :public, read_concurrency: true])
    ensure_read_receipts_table()
    ensure_seq_table()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:ensure_read_receipts_table, _from, state) do
    ensure_read_receipts_table()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:ensure_seq_table, _from, state) do
    ensure_seq_table()
    {:reply, :ok, state}
  end

  # Users
  def create_user(email) do
    id = generate_id()
    user = %{id: id, email: email}
    :ets.insert(@users_table, {id, user})
    {:ok, user}
  end

  def get_user(id), do: get_user_by(:id, id)
  def get_user_by_email(email), do: get_user_by(:email, email)

  def list_users do
    @users_table
    |> :ets.tab2list()
    |> Enum.map(fn {_k, v} -> v end)
  end

  def user_exists?(id) do
    case :ets.lookup(@users_table, id) do
      [{^id, _}] -> true
      [] -> false
    end
  end

  # Messages (per-conversation monotonic seq for deterministic ordering)
  def add_message(from_user_id, to_user_id, body) do
    GenServer.call(__MODULE__, :ensure_seq_table)
    topic = conversation_topic(from_user_id, to_user_id)
    seq = get_and_inc_seq(topic)
    id = generate_id()
    inserted_at = System.system_time(:millisecond)
    msg = %{
      id: id,
      seq: seq,
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      body: body,
      inserted_at: inserted_at
    }
    :ets.insert(@messages_table, {id, msg})
    {:ok, msg}
  end

  def conversation_topic(a, b), do: Enum.sort([a, b]) |> Enum.join(":")

  defp get_and_inc_seq(topic) do
    key = topic
    prev = case :ets.lookup(@seq_table, key) do
      [{^key, n}] -> n
      [] -> 0
    end
    next = prev + 1
    :ets.insert(@seq_table, {key, next})
    next
  end

  # Read receipts: per (topic, user_id) store the latest inserted_at they've read
  def mark_read(topic, user_id, inserted_at) when is_integer(inserted_at) do
    GenServer.call(__MODULE__, :ensure_read_receipts_table)
    key = {topic, user_id}
    prev = case :ets.lookup(@read_receipts_table, key) do
      [{^key, p}] -> p
      [] -> 0
    end
    new_at = max(prev, inserted_at)
    :ets.insert(@read_receipts_table, {key, new_at})
    {:ok, new_at}
  end

  def get_last_read_at(topic, user_id) do
    GenServer.call(__MODULE__, :ensure_read_receipts_table)
    key = {topic, user_id}
    case :ets.lookup(@read_receipts_table, key) do
      [{^key, at}] -> at
      [] -> 0
    end
  end

  def get_conversation(user_id_1, user_id_2) do
    @messages_table
    |> :ets.tab2list()
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.filter(fn msg ->
      {msg.from_user_id, msg.to_user_id} in [
        {user_id_1, user_id_2},
        {user_id_2, user_id_1}
      ]
    end)
    |> Enum.sort_by(& Map.get(&1, :seq, 0))
  end

  # Private
  defp ensure_seq_table do
    if :ets.whereis(@seq_table) == :undefined do
      :ets.new(@seq_table, [:named_table, :set, :public, read_concurrency: true])
    end
  end

  defp ensure_read_receipts_table do
    if :ets.whereis(@read_receipts_table) == :undefined do
      :ets.new(@read_receipts_table, [:named_table, :set, :public, read_concurrency: true])
    end
  end

  defp get_user_by(:id, id) do
    case :ets.lookup(@users_table, id) do
      [{^id, user}] -> {:ok, user}
      [] -> {:error, :not_found}
    end
  end

  defp get_user_by(:email, email) do
    list_users()
    |> Enum.find(&(&1.email == email))
    |> case do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  # URL-safe base64 so IDs work in query params (no + or /)
  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12), padding: false)
    |> String.replace("+", "-")
    |> String.replace("/", "_")
  end
end
