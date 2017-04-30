defmodule CouchdbAdapter do
  @moduledoc ~S"""
  CouchdbAdapter provides an implementation of the `Ecto.Adapter` behaviour for the Couchdb
  database.
  """
  @behaviour Ecto.Adapter

  defmacro __before_compile__(_env), do: nil

  @doc false
  def autogenerate(:id),        do: nil
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: nil
  # def autogenerate(:string), do: nil

  @doc false
  def loaders({:embed, _} = type, _), do: [&load_embed(type, &1)]
  # def loaders(:binary_id, type),      do: [Ecto.UUID, type]
  def loaders(_, type),               do: [type]

  defp load_embed({:embed, %{related: related, cardinality: :one}}, value) do
    {:ok, struct(related, atomize_keys(value))}
  end

  defp load_embed({:embed, %{related: related, cardinality: :many}}, values) do
    {:ok, Enum.map(values, &struct(related, atomize_keys(&1)))}
  end

  defp atomize_keys({map}), do: atomize_keys(map)
  defp atomize_keys(map), do: for {k, v} <- map, do: {String.to_atom(k), v}

  @doc false
  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  # def dumpers(:binary_id, type),      do: [type, Ecto.UUID]
  def dumpers(_, type),               do: [type]

  defmodule Noop do
    @moduledoc false
    def start_link, do: {:ok, self()}
  end

  def child_spec(_repo, _options) do
    import Supervisor.Spec
    worker(Noop, [])
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
  @lint {Credo.Check.Refactor.FunctionArity, false} # arity from Ecto.Adapter behaviour
  def insert(_repo, meta, fields, _on_conflict, returning, _options) do
    with server <- :couchbeam.server_connection("localhost", 5984, "", []),
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

  @lint {Credo.Check.Refactor.FunctionArity, false} # arity from Ecto.Adapter behaviour
  @doc false
  def insert_all(_repo, schema_meta, _header, list, _on_conflict, returning, _options) do
    with server <- :couchbeam.server_connection("localhost", 5984),
         {:ok, db} <- :couchbeam.open_db(server, db_name(schema_meta)),
         {:ok, result} <- :couchbeam.save_docs(db, Enum.map(list, &to_doc(&1)))
    do
      if returning == [] do
        {length(result), nil}
      else
        {length(result), Enum.map(result, fn({fields}) -> returning(returning, fields) end)}
      end
    end
  end

  @spec db_name(Ecto.Adapter.schema_meta) :: String.t
  defp db_name(%{schema: schema}), do: schema.__schema__(:source)
  defp db_name({{db_name, _}}), do: db_name

  @spec to_doc(Keyword.t | Map.t) :: {[{String.t, any}]}
  def to_doc(fields) do
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
  defp to_doc_value(nil), do: :null
  defp to_doc_value(value), do: value

  defp returning(returning, fields) do
    for field_name <- returning, do: normalize(field_name, fields)
  end
  defp normalize(field_name, fields) do
    {_string_key, value} = List.keyfind(fields, to_string(field_name), 0)
    {field_name, value}
  end

  @doc false
  def prepare(:all, query), do: {:nocache, normalize_query(query)}

  defp normalize_query(%{joins: [_|_]}), do: raise "joins are not supported"
  defp normalize_query(%{preloads: [_|_]}), do: raise "preloads are not supported"
  defp normalize_query(%{havings: [_|_]}), do: raise "havings are not supported"
  defp normalize_query(%{distinct: d}) when d != nil, do: raise "distinct is not supported"
  defp normalize_query(%{select: %{expr: {:&, _, [0]},
                                   fields: [{:&, _, [0, _fields, _]}]},
                         sources: {{_db_name, schema}}
                        } = query) do
    # IO.inspect Map.from_struct(query), label: "normalize_query"
    {view, options} = process_wheres(query.wheres, schema)
    %{view: view, options: [include_docs: true] ++ options}
  end
  defp normalize_query(query) do
    raise "Unsupported query: #{inspect Map.from_struct query}"
  end

  defp process_wheres([], schema), do: {{schema.__schema__(:default_design), "all"}, []}
  defp process_wheres([where], schema), do: process_where(where, schema)
  defp process_wheres(wheres, _schema), do: raise("Only 1 where clause is allowed: #{inspect wheres}")

  defp process_where(%Ecto.Query.BooleanExpr{op: :and, expr: expr}, schema) do
    process_and_expr(expr, schema)
  end
  defp process_where(expr, _), do: raise "Unsupported where clause: #{inspect expr}"

  defp process_and_expr(expr, schema) do
    case expr do
      {:==, _ , [lhs, rhs]} -> process_eq(lhs, rhs, schema)
      {:in, _ , [lhs, rhs]} -> process_in(lhs, rhs, schema)
      {:>=, _ , [lhs, rhs]} -> process_gt(lhs, rhs, schema)
      {:<=, _ , [lhs, rhs]} -> process_lt(lhs, rhs, schema)
      {:and, _, exprs} -> Enum.reduce(exprs, {nil, []}, &merge_and_expressions(&1, &2, schema))
      _ -> raise "Unsupported expression: #{inspect expr}"
    end
  end

  defp merge_and_expressions(expr, {view, opts}, schema) do
    {new_view, new_opts} = process_and_expr(expr, schema)
    if view && view != new_view do
      raise("""
            Detected view #{inspect view}, but got #{inspect new_view}
            from expression #{inspect expr}
            """)
    else
      {new_view, Keyword.merge(opts, new_opts, &solve_and_opts_conflict/3)}
    end
  end

  defp solve_and_opts_conflict(key, current_value, new_value)
  # Combine multiple in by using the intersection of keys
  defp solve_and_opts_conflict(:keys, current, new), do: current -- (current -- new)
  defp solve_and_opts_conflict(key, current, new) do
    raise("Tried to assign #{inspect new} to #{inspect key}, with current value #{inspect current}")
  end


  defp process_eq({{:., _, [{:&, _, [0]}, view]}, _, _}, rhs, schema) do
    {{schema.__schema__(:default_design), to_string(view)}, key: rhs}
  end

  defp process_in({{:., _, [{:&, _, [0]}, view]}, _, _}, rhs, schema) do
    {{schema.__schema__(:default_design), to_string(view)}, keys: rhs}
  end

  defp process_gt({{:., _, [{:&, _, [0]}, view]}, _, _}, rhs, schema) do
    {{schema.__schema__(:default_design), to_string(view)}, startkey: rhs}
  end
  defp process_lt({{:., _, [{:&, _, [0]}, view]}, _, _}, rhs, schema) do
    {{schema.__schema__(:default_design), to_string(view)}, endkey: rhs}
  end

  @lint {Credo.Check.Refactor.FunctionArity, false} # arity from Ecto.Adapter behaviour
  @doc false
  def execute(_repo, meta, {_cache, query}, _params, preprocess, _options) do
    with server <- :couchbeam.server_connection("localhost", 5984),
         {:ok, db} <- :couchbeam.open_db(server, db_name(meta.sources)),
         {:ok, data} <- :couchbeam_view.fetch(db, query.view, query.options)
    do
      {records, count} = Enum.map_reduce(data, 0, &{process_result(&1, preprocess, meta.fields), &2 + 1})
      {count, records}
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  defp process_result(record, process, ast) do
    case doc = :couchbeam_doc.get_value("value", record) do
      :undefined -> raise "Document not found on result: #{inspect record}"
      _ -> process_doc(doc, process, ast)
    end
  end

  defp process_doc(:undefined, _, _), do: :undefined
  defp process_doc(doc, process, ast) do
    Enum.map(ast, fn {:&, _, [_, fields, _]} = expr when is_list(fields) ->
      data = fields |> Enum.map(&:couchbeam_doc.get_value(to_string(&1), doc, nil))
      process.(expr, data, nil)
    end)
  end
end
