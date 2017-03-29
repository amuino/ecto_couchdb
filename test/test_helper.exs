ExUnit.start()

defmodule Repo do
  use Ecto.Repo, otp_app: :couchdb_adapter
end

defmodule Grant do
  use Ecto.Schema
  embedded_schema do
    field :user, :string
    field :access, :string
  end
end

defmodule Stats do
  use Ecto.Schema
  @primary_key false
  embedded_schema do
    field :visits, :integer
    field :time, :integer
  end
end

defmodule View do
  @behaviour Ecto.Type

  def cast(_), do: raise "not implemented"
  def dump(_), do: {:ok, nil}
  def load(_), do: raise "not implemented"
  def type, do: View
end

defmodule Post do
  use Ecto.Schema
  @primary_key {:_id, :binary_id, autogenerate: true}

  schema "posts" do
    field :title, :string
    field :body, :string
    field :_rev, :string, read_after_writes: true
    embeds_many :grants, Grant
    embeds_one :stats, Stats

    field :by_id, View, opts: [:_id]
  end
end

defmodule DatabaseCleaner do
  def ensure_clean_db!(schema) do
    server = :couchbeam.server_connection
    db_name = schema.__schema__(:source)
    if :couchbeam.db_exists(server, db_name) do
      :couchbeam.delete_db(server, db_name)
    end
    {:ok, db} = :couchbeam.create_db(server, db_name)
    db
  end
end
