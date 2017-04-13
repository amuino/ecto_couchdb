defmodule Couchdb.Design do
  @moduledoc ~S"""
  Couchdb.Design provides macros to declare the mappings of elements of couchdb design documents
  inside an `Ecto.Schema`.

  It provides the `designs` macro inside of which multiple `design` blocks can exists (one per
  design document that needs to be mapped). Each of the `design` blocks contains `view`
  declarations.

  Views are declared with a name and the types of each element of their keys. They can be used
  when building an `Ecto.Query` as regular fields in other adapters. Given that Couchdb views do
  not allow ad-hoc queries, the supported operators and the complexity of the queries is a lot more
  restricted than on SQL adapters.

  ## Example
       defmodule Flower do
         use Ecto.Schema
         use Couchdb.Design
         schema __MODULE__ do
           designs do
             design __MODULE__ do
               view :by_name, [:string]
             end
           end
         end
       end

  ## Reflection
  On top of the reflection methods provided by `Ecto.Schema`, `Couchdb.Design` provides the
  following:

  * `__schema__(:designs)` - Returns the names of all defined designs
  * `__schema__(:default_design)` - Returns the name of the schema used by the default views (`all`)
    when they are not explicitly given in an `Ecto.Query`.
  * `__schema__(:views)` - Returns tuples of `{design_name, view_name}` for all defined views
  * `__schema__(:view, {design, name})` - Returns the key types for the given design and view
  """

  defmacro __using__(_) do
    quote do
      import Couchdb.Design, only: [designs: 1]
    end
  end

  @doc ~S"""
  Provides the context for mapping individual `design` documents.

  Inside this macro, `design` is made available.
  """
  defmacro designs(do: block) do
    quote do
      Module.register_attribute(__MODULE__, :designs, accumulate: true)
      fn ->
        import Couchdb.Design, only: [design: 2]
        unquote(block)
      end.()
      Module.eval_quoted(__ENV__, [
        (def __schema__(:designs), do: @designs),
        (def __schema__(:default_design), do: inspect(__MODULE__)),
        (def __schema__(:views), do: @views),
        (def __schema__(:view, _), do: nil)
      ])
    end
  end

  @doc ~S"""
  Defines a design document given a name and the view definitions

  Inside this macro, `view` is made available.
  """
  defmacro design(design_name, do: block) do
    quote do
      name = case unquote(design_name) do
               x when is_atom(x) -> inspect(x)
               x -> x
             end
      Module.put_attribute(__MODULE__, :designs, name)
      Module.put_attribute(__MODULE__, :current_design, name)
      Module.register_attribute(__MODULE__, :views, accumulate: true)
      fn ->
        import Couchdb.Design, only: [view: 2]
        unquote(block)
      end.()
      Module.delete_attribute(__MODULE__, :current_design)
    end
  end

  @doc ~S"""
  Defines a couchdb view given its name and the types of the elements in its key.
  Views can be used instead of field names in `Ecto.Query`.

  ## Parameters
  * `name`: can be a `String` or an atom representing the module name
  * `types`: is a non-empty array of the types of each position of the view key
  """
  defmacro view(name, types) do
    quote do
      Module.put_attribute(__MODULE__, :views, {@current_design, unquote(name)})
      design = Module.get_attribute(__MODULE__, :current_design)
      Module.put_attribute(__MODULE__, :ecto_fields, {unquote(name), Couchdb.View})
      Module.eval_quoted(__ENV__, [
        (def __schema__(:view, {@current_design, unquote(name)}), do: unquote(types))
      ])
    end
  end
end
