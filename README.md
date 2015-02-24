Phoenix Pubsub - RabbitMQ Adapter
=================================

RabbitMQ adapter for Phoenix's PubSub layer.

## Usage

Add `phoenix_pubsub_rabbitmq` as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:phoenix_pubsub_rabbitmq, github: "pma/phoenix_pubsub_rabbitmq"}]
end
```

You should also update your application list to include `:amqp`:

```elixir
def application do
  [applications: [:phoenix_pubsub_rabbitmq]]
end
```

Edit your Phoenix application Endpoint configuration:

      config :my_app, MyApp.Endpoint,
        ...
        pubsub: [adapter: Phoenix.PubSub.RabbitMQ,
                 options: [host: "localhost"]


The following options are supported:

    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`
    * `options` - The optional RabbitMQ options:
      * `host` - The hostname of the broker (defaults to \"localhost\");
      * `port` - The port the broker is listening on (defaults to `5672`);
      * `username` - The name of a user registered with the broker (defaults to \"guest\");
      * `password` - The password of user (defaults to \"guest\");
      * `virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
      * `heartbeat` - The hearbeat interval in seconds (defaults to `0` - turned off);
      * `connection_timeout` - The connection timeout in milliseconds (defaults to `infinity`);
      * `pool_size` - Number of active connections to the broker
