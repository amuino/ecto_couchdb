defmodule Stats do
  use Ecto.Schema
  @primary_key false
  embedded_schema do
    field :visits, :integer
    field :time, :integer
  end
end
