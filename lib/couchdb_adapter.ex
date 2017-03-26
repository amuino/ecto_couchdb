defmodule CouchdbAdapter do
  @behaviour Ecto.Adapter

  defmacro __before_compile__(_env), do: nil

  @doc false
  def autogenerate(:id),        do: nil
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: nil
  def autogenerate(:string), do: nil

  @doc false
  def loaders({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.load_embed(type, &1)]
  # def loaders(:binary_id, type),      do: [Ecto.UUID, type]
  def loaders(_, type),               do: [type]

  @doc false
  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  # def dumpers(:binary_id, type),      do: [type, Ecto.UUID]
  def dumpers(_, type),               do: [type]

  def child_spec(_repo, _options) do
    [] # no children at the moment
  end

  def ensure_all_started(_repo, type) do
    Application.ensure_all_started(:couchbeam, type)
  end

  @doc false
  # Dev notes:
  # - repo: is the module from which we were called (the one using Exto.Repo)
  # - meta: is https://hexdocs.pm/ecto/Ecto.Adapter.html#t:schema_meta/0
  # - fields: is a Keyword.t with field-value pairs
  # - on_conflict: https://hexdocs.pm/ecto/Ecto.Adapter.html#t:on_conflict/0
  # - returning: list of atoms of fields whose value needs to be returned
  # - options: ??? Seems to be a Keyword.t (but the actual type is options). Arrives as [skip_transaction: true]
  def insert(_repo, meta, fields, _on_conflict, returning, _options) do
    with server <- :couchbeam.server_connection("localhost", 5984),
         {:ok, db} <- :couchbeam.open_db(server, db_name(meta)),
         {:ok, {new_fields}} <- :couchbeam.save_doc(db, to_doc(fields))
      do
        {:ok, returning(returning, new_fields)}
      else
        {:error, :conflict} ->
          # Map the conflict to the format of SQL constraints
          {:invalid, [unique: "#{db_name(meta)}_id_index"]}
    end
  end

  @spec db_name(Ecto.Adapter.schema_meta) :: String.t
  defp db_name(%{schema: schema}), do: schema.__schema__(:source)

  @spec to_doc(Keyword.t) :: {[{String.t, any}]}
  defp to_doc(fields) do
    kv_list = for {name, value} <- fields do
      {to_string(name), to_doc_value(value)}
    end
    {kv_list}
  end
  defp to_doc_value(list) when is_list(list) do
    values = for i <- list, do: to_doc_value(i)
    {values}
  end
  defp to_doc_value(map) when is_map(map) do
    kv_list = for {name, value} <- map, do: {to_string(name), to_doc_value(value)}
    {kv_list}
  end
  defp to_doc_value(value), do: value

  defp returning(returning, fields) do
    for field_name <- returning, do: normalize(field_name, fields)
  end
  defp normalize(field_name, fields) do
    {_string_key, value} = List.keyfind(fields, to_string(field_name), 0)
    {field_name, value}
  end
end
