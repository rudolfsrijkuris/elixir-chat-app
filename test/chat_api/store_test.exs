defmodule ChatApi.StoreTest do
  use ExUnit.Case, async: false

  describe "users and messages" do
    test "conversation returns messages in seq order" do
      email_a = "store_order_#{System.unique_integer([:positive])}@test.com"
      email_b = "store_order_#{System.unique_integer([:positive])}@test.com"
      {:ok, a} = ChatApi.Store.create_user(email_a)
      {:ok, b} = ChatApi.Store.create_user(email_b)

      {:ok, m1} = ChatApi.Store.add_message(a.id, b.id, "first")
      {:ok, m2} = ChatApi.Store.add_message(b.id, a.id, "second")
      {:ok, m3} = ChatApi.Store.add_message(a.id, b.id, "third")

      conv = ChatApi.Store.get_conversation(a.id, b.id)
      assert length(conv) == 3
      assert [^m1, ^m2, ^m3] = conv
      assert m1.seq < m2.seq and m2.seq < m3.seq
    end
  end

  describe "read receipts" do
    test "mark_read and get_last_read_at" do
      email_a = "store_read_#{System.unique_integer([:positive])}@test.com"
      email_b = "store_read_#{System.unique_integer([:positive])}@test.com"
      {:ok, a} = ChatApi.Store.create_user(email_a)
      {:ok, b} = ChatApi.Store.create_user(email_b)
      topic = ChatApi.Store.conversation_topic(a.id, b.id)

      assert ChatApi.Store.get_last_read_at(topic, b.id) == 0

      {:ok, msg} = ChatApi.Store.add_message(a.id, b.id, "hi")
      ChatApi.Store.mark_read(topic, b.id, msg.inserted_at)
      assert ChatApi.Store.get_last_read_at(topic, b.id) == msg.inserted_at

      # only moves forward
      ChatApi.Store.mark_read(topic, b.id, msg.inserted_at - 1000)
      assert ChatApi.Store.get_last_read_at(topic, b.id) == msg.inserted_at
    end
  end
end
