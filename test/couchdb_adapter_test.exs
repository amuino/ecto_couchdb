defmodule CouchdbAdapterTest do
  use ExUnit.Case
  doctest CouchdbAdapter

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

  defmodule Post do
    use Ecto.Schema
    @primary_key {:_id, :binary_id, autogenerate: true}

    schema "posts" do
      field :title, :string
      field :body, :string
      field :_rev, :string, read_after_writes: true
      embeds_many :grants, Grant
      embeds_one :stats, Stats
    end
  end

  setup do
    %{
      db: ensure_db_exists!(__MODULE__.Post),
      post: %Post{title: "how to write and adapter", body: "Don't know yet"},
      grants: [%Grant{user: "admin", access: "all"}, %Grant{user: "other", access: "read"}]
    }
  end

  def ensure_db_exists!(schema) do
    server = :couchbeam.server_connection
    db_name = schema.__schema__(:source)
    if :couchbeam.db_exists(server, db_name) do
      :couchbeam.delete_db(server, db_name)
    end
    {:ok, db} = :couchbeam.create_db(server, db_name)
    db
  end

  test "can insert and generate id/rev", %{post: post} do
    {:ok, result} = Repo.insert(post)
    assert has_id_and_rev?(result)
  end

  test "can insert with locally generated id", %{post: post} do
    post = struct(post, _id: "FOO")
    {:ok, result} = Repo.insert(post)
    assert has_id_and_rev?(result)
    assert result._id == "FOO"
  end

  test "can not insert the same id twice", %{post: post} do
    post = struct(post, _id: "FOO")
    assert {:ok, _} = Repo.insert(post)
    exception = assert_raise Ecto.ConstraintError, fn -> Repo.insert(post) end
    assert exception.constraint == "posts_id_index"
  end

  test "can handle insert conflicts through changesets", %{post: post} do
    import Ecto.Changeset
    params = Map.from_struct(post)
    changeset = cast(%Post{}, %{ params | _id: "FOO"}, [:title, :body, :_id])
                |> unique_constraint(:id)
    assert {:ok, _} = Repo.insert(changeset)
    assert {:error, changeset} = Repo.insert(changeset)
    assert changeset.errors[:id] != nil
    assert changeset.errors[:id] == {"has already been taken", []}
  end

  test "can insert with embeds", %{post: post, grants: grants} do
    post = struct(post, grants: grants)
    {:ok, result} = Repo.insert(post)
    assert has_id_and_rev?(result)
  end

  test "can insert embeds without ids", %{post: post} do
    post = struct(post, stats: %Stats{visits: 12, time: 892})
    {:ok, result} = Repo.insert(post)
    assert has_id_and_rev?(result)
  end

  defp has_id_and_rev?(resource) do
    assert resource._id
    assert resource._rev
  end

end
