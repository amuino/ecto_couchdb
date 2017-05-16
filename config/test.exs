use Mix.Config

config :couchdb_adapter, Repo,
  adapter: CouchdbAdapter,
  hostname: "localhost",
  port: 5984,
  pool_size: 5,
  pool_timeout: 2000
