ExUnit.start()

defmodule Repo do
  use Ecto.Repo, otp_app: :couchdb_adapter
end

defmodule Couchdb do
  defmodule View do
    @behaviour Ecto.Type

    def cast(_), do: raise "not implemented"
    def dump(value), do: {:ok, value}
    def load(_), do: raise "not implemented"
    def type, do: View
  end

  defmodule Design do
    defmacro __using__(_) do
      quote do
        import Design, only: [designs: 1, design: 2, view: 2]
      end
    end

    defmacro designs(do: block) do
      quote do
        Module.register_attribute(__MODULE__, :designs, accumulate: true)
        unquote(block)
        Module.eval_quoted(__ENV__, [
          (def __schema__(:designs), do: @designs),
          (def __schema__(:default_design), do: inspect(__MODULE__))
        ])
      end
    end

    defmacro design(design_name, do: block) do
      quote do
        name = case unquote(design_name) do
                 x when is_atom(x) -> inspect(x)
                 x -> x
               end
        Module.put_attribute(__MODULE__, :designs, name)
        Module.put_attribute(__MODULE__, :current_design, name)
        unquote(block)
        Module.delete_attribute(__MODULE__, :current_design)
        Module.eval_quoted(__ENV__, [
          (def __schema__(:design, design_name), do: @designs)
        ])
      end
    end

    defmacro view(name, types) do
      quote do
        design = Module.get_attribute(__MODULE__, :current_design)
        Module.put_attribute(__MODULE__, :ecto_fields, {unquote(name), Couchdb.View})
      end
    end
  end
end

# Load support files
files = Path.wildcard("#{__DIR__}/support/**/*.exs")
Enum.each files, &Code.require_file(&1, __DIR__)
