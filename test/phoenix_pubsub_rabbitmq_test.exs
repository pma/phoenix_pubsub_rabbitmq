defmodule PhoenixRabbitmqPubsubTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub
  require Logger

  defmodule PubSub.BroadcastError do
    defexception [:message]
  end

  defmodule PubSub do
    alias PubSub.BroadcastError

    def subscribe(server, pid, topic, opts \\ []) do
      GenServer.call(server, {:subscribe, pid, topic, opts})
    end

    def unsubscribe(server, pid, topic) do
      GenServer.call(server, {:unsubscribe, pid, topic})
    end

    def subscribers(server, topic) do
      GenServer.call(server, {:subscribers, topic})
    end

    def broadcast(server, topic, message) do
      GenServer.call(server, {:broadcast, :none, topic, message})
    end

    def broadcast_from(server, from_pid, topic, message) do
      GenServer.call(server, {:broadcast, from_pid, topic, message})
    end

    def broadcast!(server, topic, message, broadcaster \\ __MODULE__) do
      case broadcaster.broadcast(server, topic, message) do
        :ok -> :ok
        {:error, reason} -> raise BroadcastError, message: reason
      end
    end

    def broadcast_from!(server, from_pid, topic, message, broadcaster \\ __MODULE__) do
      case broadcaster.broadcast_from(server, from_pid, topic, message) do
        :ok -> :ok
        {:error, reason} -> raise BroadcastError, message: reason
      end
    end

  end

  @adapters [
    Phoenix.PubSub.RabbitMQ
  ]

  def spawn_pid do
    spawn fn -> :timer.sleep(:infinity) end
  end

  def rand_server_name do
    :crypto.rand_bytes(16) |> Base.encode16 |> String.to_atom
  end

  defmodule FailedBroadcaster do
    def broadcast(_server, _topic, _msg), do: {:error, :boom}
    def broadcast_from(_server, _from_pid, _topic, _msg), do: {:error, :boom}
  end

  for adapter <- @adapters do
    @adapter adapter

    setup do
      server_name = rand_server_name()
      {:ok, _super_pid} = @adapter.start_link(server_name, [])
      {:ok, server: server_name}
    end

    test "#{inspect @adapter} #subscribers, #subscribe, #unsubscribe", context do
      pid = spawn_pid
      assert Enum.empty?(PubSub.subscribers(context[:server], "topic4"))
      assert PubSub.subscribe(context[:server], pid, "topic4")
      assert PubSub.subscribers(context[:server], "topic4") |> Enum.to_list == [pid]
      assert PubSub.unsubscribe(context[:server], pid, "topic4")
      assert Enum.empty?(PubSub.subscribers(context[:server], "topic4"))
    end

    test "#{inspect @adapter} subscribe/3 with link does not down adapter", context do
      server_pid = Process.whereis(context[:server])
      assert Process.alive?(server_pid)
      pid = spawn_pid

      assert Enum.empty?(PubSub.subscribers(context[:server], "topic4"))
      assert PubSub.subscribe(context[:server], pid, "topic4", link: true)
      Process.exit(pid, :kill)
      refute Process.alive?(pid)
      assert Process.alive?(server_pid)
    end

    test "#{inspect @adapter} subscribe/3 with link downs subscriber", context do
      server_pid = Process.whereis(context[:server])
      assert Process.alive?(server_pid)

      pid = spawn_pid
      non_linked_pid = spawn_pid
      non_linked_pid2 = spawn_pid

      assert PubSub.subscribe(context[:server], pid, "topic4", link: true)
      assert PubSub.subscribe(context[:server], non_linked_pid, "topic4")
      assert PubSub.subscribe(context[:server], non_linked_pid2, "topic4", link: false)

      Process.exit(server_pid, :kill)
      refute Process.alive?(server_pid)
      refute Process.alive?(pid)
      assert Process.alive?(non_linked_pid)
      assert Process.alive?(non_linked_pid2)
    end

    test "#{inspect @adapter} broadcast/3 and broadcast!/3 publishes message to each subscriber", context do
      assert PubSub.subscribers(context[:server], "topic9") |> Enum.to_list == []
      PubSub.subscribe(context[:server], self, "topic9")
      assert PubSub.subscribers(context[:server], "topic9") |> Enum.to_list == [self]
      :ok = PubSub.broadcast(context[:server], "topic9", :ping)
      assert_receive :ping
      :ok = PubSub.broadcast!(context[:server], "topic9", :ping)
      assert_receive :ping
      assert PubSub.subscribers(context[:server], "topic9") |> Enum.to_list == [self]
    end

    test "#{inspect @adapter} broadcast!/3 and broadcast_from!/4 raise if broadcast fails", context do
      PubSub.subscribe(context[:server], self, "topic9")
      assert PubSub.subscribers(context[:server], "topic9") |> Enum.to_list == [self]
      assert_raise PubSub.BroadcastError, fn ->
        PubSub.broadcast!(context[:server], "topic9", :ping, FailedBroadcaster)
      end
      assert_raise PubSub.BroadcastError, fn ->
        PubSub.broadcast_from!(context[:server], self, "topic9", :ping, FailedBroadcaster)
      end
      refute_receive :ping
    end

    test "#{inspect @adapter} broadcast_from/4 and broadcast_from!/4 skips sender", context do
      PubSub.subscribe(context[:server], self, "topic11")
      PubSub.broadcast_from(context[:server], self, "topic11", :ping)
      refute_receive :ping

      PubSub.broadcast_from!(context[:server], self, "topic11", :ping)
      refute_receive :ping
    end

    test "#{inspect @adapter} processes automatically removed from topic when killed", context do
      pid = spawn_pid
      assert PubSub.subscribe(context[:server], pid, "topic12")
      assert PubSub.subscribers(context[:server], "topic12") |> Enum.to_list == [pid]
      Process.exit pid, :kill
      :timer.sleep 50 # wait until adapter removes dead pid
      assert PubSub.subscribers(context[:server], "topic12") |> Enum.to_list == []
    end
  end
end
