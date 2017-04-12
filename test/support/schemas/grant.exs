defmodule Grant do
  use Ecto.Schema
  embedded_schema do
    field :user, :string
    field :access, :string
  end
end
