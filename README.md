Phoenix Pubsub - RabbitMQ Adapter
=================================

RabbitMQ adapter for the Phoenix framework PubSub layer.

## Usage

Add `phoenix_pubsub_rabbitmq` as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:phoenix_pubsub_rabbitmq, "0.0.1"}]
end
```

You should also update your application list to include `:phoenix_pubsub_rabbitmq`:

```elixir
def application do
  [applications: [:phoenix_pubsub_rabbitmq]]
end
```

Edit your Phoenix application Endpoint configuration:

      config :my_app, MyApp.Endpoint,
        ...
        pubsub: [name: MyApp.PubSub,
                 adapter: Phoenix.PubSub.RabbitMQ,
                 options: [host: "localhost"]


The following options are supported:

      * `host` - The hostname of the broker (defaults to \"localhost\");
      * `port` - The port the broker is listening on (defaults to `5672`);
      * `username` - The name of a user registered with the broker (defaults to \"guest\");
      * `password` - The password of user (defaults to \"guest\");
      * `virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
      * `heartbeat` - The connection hearbeat interval in seconds (defaults to `0` - turned off);
      * `connection_timeout` - The connection timeout in milliseconds (defaults to `infinity`);
      * `pool_size` - Number of active connections to the broker

## Notes

  * An Exchange is declared with the name of the Phoenix PubSub server (example: MyApp.PubSub)
  * When subscribing to a topic:
      * a Queue with a server assigned name is declared;
      * the Queue is bound to the Exchange using the `topic` as routing key;
      * a consumer process is started. The consumer will ack each message in the Queue as it sends the payload to the subscriber pid;
  * Can be used when distributed Erlang is not an option (like when deploying to Heroku); when RabbitMQ is already a dependency (instead of Redis);
  * Uses RabbitMQ routing mechanism, delivering a message directly to a consumer process
