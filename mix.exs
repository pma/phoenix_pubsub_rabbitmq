defmodule Phoenix.PubSub.RabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_pubsub_rabbitmq,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :amqp, :poolboy]]
  end

  defp deps do
    [{:poolboy, "~> 1.4.2"},
     {:amqp, "~> 0.1.0"}]
  end
end
