use Mix.Config

config :couchdb_adapter, Repo,
  adapter: CouchdbAdapter,
  hostname: "localhost",
  port: 5984
