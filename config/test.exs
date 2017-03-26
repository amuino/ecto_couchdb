use Mix.Config

config :couchdb_adapter, CouchdbAdapterTest.Repo,
  adapter: CouchdbAdapter,
  hostname: "localhost",
  port: 5984
