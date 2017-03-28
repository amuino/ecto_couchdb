@doc """
    Test for the Ecto.Repository API, delegated to the CouchdbAdapter
"""
defmodule RepoTest do
  use ExUnit.Case

  setup do
    %{
      db: DatabaseCleaner.ensure_clean_db!(Post),
      post: %Post{title: "how to write and adapter", body: "Don't know yet"},
      grants: [%Grant{user: "admin", access: "all"}, %Grant{user: "other", access: "read"}]
    }
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
