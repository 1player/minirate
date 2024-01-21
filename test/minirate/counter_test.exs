defmodule Minirate.CounterTest do
  use ExUnit.Case

  alias Minirate.Counter

  setup do
    :mnesia.create_table(:rate_limiter, attributes: [:key, :count, :timestamp])

    on_exit(fn -> :mnesia.delete_table(:rate_limiter) end)
  end

  describe ".get_count/3 - increments by 1" do
    test "inserts entry when it's called for the first time" do
      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_now = 158_037_147_724

      assert {:ok, 1} == Counter.get_count(:rate_limiter, {"test", 1, fake_now})

      assert [{:rate_limiter, "test_1", 1, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end

    test "updates only the count when it's called more than once" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 1, fake_now})

      assert [{:rate_limiter, "test_1", 1, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_future_time = fake_now + 1_000

      assert {:ok, 2} == Counter.get_count(:rate_limiter, {"test", 1, fake_future_time})

      assert [{:rate_limiter, "test_1", 2, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end
  end

  describe ".get_count/4 - increments by n" do
    test "inserts entry when it's called for the first time" do
      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_now = 158_037_147_724
      increment = 2

      assert {:ok, 2} == Counter.get_count(:rate_limiter, {"test", 1, fake_now}, increment)

      assert [{:rate_limiter, "test_1", 2, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end

    test "updates only the count when it's called more than once" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 2, fake_now})

      assert [{:rate_limiter, "test_1", 2, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_future_time = fake_now + 1_000
      increment = 2

      assert {:ok, 4} ==
               Counter.get_count(:rate_limiter, {"test", 1, fake_future_time}, increment)

      assert [{:rate_limiter, "test_1", 4, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end
  end

  describe ".check_limit/3 - increments by 1 and checks if the limit has exceeded" do
    test "when there's no count yet" do
      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_now = 158_037_147_724
      limit = 10

      assert {:allow, 1} == Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_now})
    end

    test "when the limit is lower than the count" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 15, fake_now})

      limit = 10
      fake_future_time = fake_now + 1_000

      assert {:block, 16} ==
               Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_future_time})
    end

    test "when the limit is higher than the count" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 15, fake_now})

      limit = 20
      fake_future_time = fake_now + 1_000

      assert {:allow, 16} ==
               Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_future_time})
    end
  end

  describe ".check_limit/4 - increments by n and checks if the limit has exceeded" do
    test "when there's no count yet" do
      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})

      fake_now = 158_037_147_724
      increment = 5
      limit = 10

      assert {:allow, 5} ==
               Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_now}, increment)
    end

    test "when the limit is lower than the count" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 15, fake_now})

      increment = 6
      limit = 20
      fake_future_time = fake_now + 1_000

      assert {:block, 21} ==
               Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_future_time}, increment)
    end

    test "when the limit is higher than the count" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 15, fake_now})

      increment = 5
      limit = 20
      fake_future_time = fake_now + 1_000

      assert {:allow, 20} ==
               Counter.check_limit(:rate_limiter, {"test", 1, limit, fake_future_time}, increment)
    end
  end

  describe ".expire_keys/1 - deletes the entries older than the expiration set" do
    test "record not older" do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 1, fake_now})

      time_of_expiration = fake_now - 10_000

      Counter.expire_keys(:rate_limiter, time_of_expiration)

      assert [{:rate_limiter, "test_1", 1, fake_now}] ==
               :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end

    test "record older than expiration time " do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 1, fake_now})

      time_of_expiration = fake_now + 10_000

      Counter.expire_keys(:rate_limiter, time_of_expiration)

      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end

    test "record exactly on expiration time " do
      fake_now = 158_037_147_724
      :mnesia.dirty_write({:rate_limiter, "test_1", 1, fake_now})

      time_of_expiration = fake_now

      Counter.expire_keys(:rate_limiter, time_of_expiration)

      assert [] == :mnesia.dirty_match_object({:rate_limiter, "test_1", :_, :_})
    end
  end
end
