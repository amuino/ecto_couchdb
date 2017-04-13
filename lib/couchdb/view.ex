defmodule Couchdb.View do
  @moduledoc ~S"""
  Couchdb.View is an `Ecto.Type` representing values for couchdb view keys.

  The type is used for the schema fields generated for the views in a design

      iex> defmodule Flower do
      ...>   use Ecto.Schema
      ...>   use Couchdb.Design
      ...>   schema "posts" do
      ...>     designs do
      ...>       design __MODULE__ do
      ...>         view :by_name, [:string]
      ...>       end
      ...>     end
      ...>   end
      ...> end
      ...> Flower.__schema__(:type, :by_name) == Couchdb.View
      true
  """
  @behaviour Ecto.Type

  def cast(_), do: raise "not implemented"
  def dump(value), do: {:ok, value}
  def load(_), do: raise "not implemented"
  def type, do: View
end
