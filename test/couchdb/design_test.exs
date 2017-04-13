defmodule Couchdb.DesignTest do
  use ExUnit.Case, async: true

  describe "reflection" do
    test "__schema__(:designs) returns existing designs as [String.t]" do
      assert Post.__schema__(:designs) == ["secondary", "Post"]
    end
    test "__schema__(:default_design) returns the module name as a String.t" do
      assert Post.__schema__(:default_design) == "Post"
    end
    test "__schema__(:views) returns the view names as {String.t, atom}" do
      expected_views = [{"secondary", :by_other}, {"Post", :all}, {"Post", :by_title}]
      assert Post.__schema__(:views) == expected_views
    end
    test "__schema__(:view, {design, name}) returns the types of the keys as [atom...]" do
      assert Post.__schema__(:view, {"Post", :by_title}) == [:string]
    end
    test "__schema__(:view, {design, name}) returns nil if the view is not defined" do
      assert Post.__schema__(:view, {"Post", :not_here}) == nil
    end
  end
end
