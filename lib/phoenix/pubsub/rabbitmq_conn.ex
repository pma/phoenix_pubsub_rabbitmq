defmodule Phoenix.PubSub.RabbitMQConn do
  use GenServer
  use AMQP
  require Logger

  @reconnect_after_ms 5_000

  @moduledoc """
  Worker for pooled connections to RabbitMQ
  """

  @doc """
  Starts the server

  See `Phoenix.PubSub.RabbitMQ` for details and configuration options.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def init([opts]) do
    Process.flag(:trap_exit, true)
    send(self, :connect)
    {:ok, %{opts: opts, status: :disconnected, conn: nil}}
  end

  def handle_call(:conn, _from, %{status: :connected, conn: conn} = status) do
    {:reply, {:ok, conn}, status}
  end

  def handle_call(:conn, _from, %{status: :disconnected} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_info(:connect, state) do
    case Connection.open(state.opts) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:noreply, %{state | conn: conn, status: :connected}}
      {:error, _reason} ->
        :timer.send_after(@reconnect_after_ms, :connect)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{status: :connected} = state) do
    Logger.error "lost RabbitMQ connection. Attempting to reconnect..."
    :timer.send_after(@reconnect_after_ms, :connect)
    {:noreply, %{state | conn: nil, status: :disconnected}}
  end

  def terminate(_reason, %{conn: conn, status: :connected}) do
    try do
      Connection.close(conn)
    catch
      _, _ -> :ok
    end
  end
  def terminate(_reason, _state) do
    :ok
  end
end
