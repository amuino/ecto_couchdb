ExUnit.start()

defmodule Repo do
  use Ecto.Repo, otp_app: :couchdb_adapter
end

defmodule View do
  @behaviour Ecto.Type

  def cast(_), do: raise "not implemented"
  def dump(_), do: {:ok, nil}
  def load(_), do: raise "not implemented"
  def type, do: View
end



  end

    end
  end
end

# Load support files
files = Path.wildcard("#{__DIR__}/support/**/*.exs")
Enum.each files, &Code.require_file(&1, __DIR__)
