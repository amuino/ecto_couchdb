defmodule Post do
  use Ecto.Schema
  use Couchdb.Design
  @primary_key {:_id, :binary_id, autogenerate: true}

  schema "posts" do
    field :title, :string
    field :body, :string
    field :_rev, :string, read_after_writes: true
    embeds_many :grants, Grant
    embeds_one :stats, Stats

    designs do
      design __MODULE__ do
        view :by_title, [:string]
        view :all, [:string]
      end
      design "secondary" do
        view :by_other, [:string]
      end
    end
  end
end
