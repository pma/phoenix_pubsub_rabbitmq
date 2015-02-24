defmodule Phoenix.PubSub.RabbitMQConsumer do
  use GenServer
  use AMQP
  alias Phoenix.PubSub.RabbitMQ
  require Logger

  @prefetch_count 10

  def start_link(conn_pool, exchange, topic, pid, node_ref, link) do
    GenServer.start_link(__MODULE__, [conn_pool, exchange, topic, pid, node_ref, link])
  end

  def start(conn_pool, exchange, topic, pid, node_ref, link) do
    GenServer.start(__MODULE__, [conn_pool, exchange, topic, pid, node_ref, link])
  end

  def init([conn_pool, exchange, topic, pid, node_ref, link]) do
    Process.flag(:trap_exit, true)

    if link, do: Process.link(pid)

    case RabbitMQ.with_conn(conn_pool, fn conn ->
          {:ok, chan} = Channel.open(conn)
          Process.monitor(chan.pid)

          {:ok, %{queue: queue}} = Queue.declare(chan, "", auto_delete: true)
          :ok = Exchange.declare(chan, exchange, :direct, auto_delete: true)
          :ok = Queue.bind(chan, queue, exchange, routing_key: topic)

          _pid_monitor = Process.monitor(pid)
          :ok = Basic.qos(chan, prefetch_count: @prefetch_count)
          {:ok, consumer_tag} = Basic.consume(chan, queue, self(), exclusive: true)
          {:ok, chan, consumer_tag}
        end) do
      {:ok, chan, consumer_tag} ->
        {:ok, %{chan: chan, pid: pid, node_ref: node_ref, consumer_tag: consumer_tag}}
      {:error, :disconnected} ->
        {:stop, :disconnected}
    end
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def handle_call(:stop, _from, %{chan: chan, consumer_tag: consumer_tag} = state) do
    {:ok, ^consumer_tag} = Basic.cancel(chan, consumer_tag)
    receive do
      {:basic_cancel_ok, %{consumer_tag: ^consumer_tag}} ->
        Channel.close(state.chan)
        {:stop, :normal, :ok, state}
    end
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    {:noreply, %{state | consumer_tag: consumer_tag}}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _}}, state) do
    Channel.close(state.chan)
    {:stop, {:shutdown, :basic_cancel}, state}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: delivery_tag}}, state) do
    {remote_node_ref, from_pid, msg} = :erlang.binary_to_term(payload)
    if from_pid == :none or remote_node_ref != state.node_ref and from_pid != state.pid do
      send(state.pid, msg)
    end
    Basic.ack(state.chan, delivery_tag)
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, %{pid: pid} = state) do
    # Subscriber died. link: true
    {:stop, {:shutdown, reason}, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{pid: pid} = state) do
    # Subscriber died. link: false
    {:stop, {:shutdown, reason}, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{chan: %{pid: pid}} = state) do
    # Subscriber died. link: true
    {:stop, {:shutdown, reason}, state}
  end

  def terminate(_reason, state) do
    try do
      Channel.close(state.chan)
    catch
      _, _ -> :ok
    end
  end

end
