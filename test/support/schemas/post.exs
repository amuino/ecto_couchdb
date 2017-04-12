defmodule Post do
  use Ecto.Schema
  use Design
  @primary_key {:_id, :binary_id, autogenerate: true}

  schema "posts" do
    field :title, :string
    field :body, :string
    field :_rev, :string, read_after_writes: true
    embeds_many :grants, Grant
    embeds_one :stats, Stats

    field :by_id, View
    designs do
      design "foo", do: nil
      design "bar", do: nil
      IO.puts "Hey ya!"
    end
  end
end

IO.inspect Post.__schema__(:designs)
