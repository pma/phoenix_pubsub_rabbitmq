defmodule Phoenix.PubSub.RabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_pubsub_rabbitmq,
     version: "0.0.1",
     elixir: "~> 1.0",
     description: description,
     package: package,
     source_url: "https://github.com/pma/phoenix_pubsub_rabbitmq",
     deps: deps,
     docs: [readme: "README.md", main: "README"]]
  end

  def application do
    [applications: [:logger, :amqp, :poolboy]]
  end

  defp deps do
    [{:poolboy, "~> 1.4.2"},
     {:amqp, "~> 0.1.3"}]
  end

  defp description do
    """
    RabbitMQ adapter for the Phoenix framework PubSub layer.
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     contributors: ["Paulo Almeida"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/pma/phoenix_pubsub_rabbitmq"}]
  end
end
