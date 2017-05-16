defmodule DatabaseCleaner do
  def ensure_clean_db!(repo, schema) do
    config = Application.get_env(:couchdb_adapter, repo)
    server = :couchbeam.server_connection(config[:hostname], config[:port], "", [])
    db_name = schema.__schema__(:source)
    if :couchbeam.db_exists(server, db_name) do
      :couchbeam.delete_db(server, db_name)
    end
    {:ok, db} = :couchbeam.create_db(server, db_name)
    db
  end
end
