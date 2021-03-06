defmodule Hex.MixTest do
  use HexTest.Case

  defmodule Simple do
    def project do
      [ app: :simple,
        version: "0.1.0",
        deps: [ { :ecto, "0.2.0" } ] ]
    end
  end

  defmodule SimpleOld do
    def project do
      [ app: :simple,
        version: "0.1.0",
        deps: [ { :ecto, "~> 0.2.1" } ] ]
    end
  end

  defmodule Override do
    def project do
      [ app: :override,
        version: "0.1.0",
        deps: [ { :ecto, "0.2.0" },
                { :ex_doc, "~> 0.1.0", override: true }] ]
    end
  end

  defmodule NonHexDep do
    def project do
      [ app: :non_hex_dep,
        version: "0.1.0",
        deps: [ { :has_hex_dep, path: fixture_path("has_hex_dep") } ] ]
    end
  end

  defmodule OverrideWithGit do
    def project do
      [ app: :override_with_git,
        version: "0.1.0",
        deps: [ { :postgrex, nil },
                { :ex_doc, path: fixture_path("ex_doc"), override: true }] ]
    end
  end

  defmodule Optional do
    def project do
      [ app: :optional,
        version: "0.1.0",
        deps: [ { :only_doc, nil } ] ]
    end
  end

  defmodule WithOptional do
    def project do
      [ app: :with_optional,
        version: "0.1.0",
        deps: [ { :only_doc, nil },
                { :ex_doc, "0.0.1" } ] ]
    end
  end

  setup do
    Hex.Registry.start(registry_path: tmp_path("hex.ets"))
    :ok
  end

  @tag :integration
  test "deps.get" do
    Mix.Project.push Simple

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)
      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting ecto (package)"] }
      assert_received { :mix_shell, :info, ["* Getting postgrex (package)"] }
      assert_received { :mix_shell, :info, ["* Getting ex_doc (package)"] }

      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* ecto 0.2.0 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.0"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* postgrex 0.2.0 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.0"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* ex_doc 0.0.1 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.0.1"] }
      assert_received { :mix_shell, :info, ["  ok"] }
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  @tag :integration
  test "deps.update" do
    Mix.Project.push Simple

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)

      # `deps.get` to set up lock
      Mix.Task.run "deps.get"

      purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
              Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]

      Mix.ProjectStack.clear_cache
      Mix.Project.pop
      Mix.Project.push SimpleOld

      Mix.Task.run "deps.update", ["ecto"]

      assert_received { :mix_shell, :info, ["* Updating ecto (package)"] }
      assert_received { :mix_shell, :info, ["* Updating postgrex (package)"] }
      assert_received { :mix_shell, :info, ["* Updating ex_doc (package)"] }

      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* ecto 0.2.1 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.1"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* postgrex 0.2.1 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.1"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* ex_doc 0.1.0 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.1.0"] }
      assert_received { :mix_shell, :info, ["  ok"] }
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  @tag :integration
  test "deps.get with override" do
    Mix.Project.push Override

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)

      Mix.Task.run "deps.get"
      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* ecto 0.2.0 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.0"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* postgrex 0.2.1 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.2.1"] }
      assert_received { :mix_shell, :info, ["  ok"] }

      assert_received { :mix_shell, :info, ["* ex_doc 0.1.0 (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.1.0"] }
      assert_received { :mix_shell, :info, ["  ok"] }
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  @tag :integration
  test "deps.get with non hex dependency that has hex dependency" do
    Mix.Project.push NonHexDep

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)
      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting ecto (package)"] }
      assert_received { :mix_shell, :info, ["* Getting postgrex (package)"] }
      assert_received { :mix_shell, :info, ["* Getting ex_doc (package)"] }
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, HasHexDep.Mixfile, Sample.Mixfile ]
  end

  @tag :integration
  test "do not fetch git children of hex dependencies" do
    Mix.Project.push SimpleOld

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)
      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting ecto (package)"] }

      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* ecto (package)"] }
      refute_received { :mix_shell, :info, ["* sample" <> _] }
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  @tag :integration
  test "override hex dependency with path dependency" do
    Mix.Project.push OverrideWithGit

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)
      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting postgrex (package)"] }

      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* postgrex (package)"] }
      refute_received { :mix_shell, :info, ["* ex_doc (package)"] }
      assert_received { :mix_shell, :info, ["* ex_doc" <> _] }
    end
  after
    purge [ Postgrex.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end

  @tag :integration
  test "optional dependency" do
    Mix.Project.push Optional

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)

      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting only_doc (package)"] }
      refute_received { :mix_shell, :info, ["* Getting ex_doc (package)"] }

      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* only_doc (package)"] }
      refute_received { :mix_shell, :info, ["* ex_doc (package)"] }
    end
  after
    purge [ Only_doc.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end


  @tag :integration
  test "with optional dependency" do
    Mix.Project.push WithOptional

    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)

      Mix.Task.run "deps.get"

      assert_received { :mix_shell, :info, ["* Getting only_doc (package)"] }
      assert_received { :mix_shell, :info, ["* Getting ex_doc (package)"] }

      Mix.Task.run "deps"

      assert_received { :mix_shell, :info, ["* only_doc (package)"] }
      assert_received { :mix_shell, :info, ["* ex_doc (package)"] }
      assert_received { :mix_shell, :info, ["  locked at 0.0.1"] }
    end
  after
    purge [ Only_doc.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end

  test "config" do
    in_tmp fn ->
      System.put_env("MIX_HOME", System.cwd!)
      assert Hex.Mix.read_config == []

      Hex.Mix.update_config([key: "value"])
      assert Hex.Mix.read_config == [key: "value"]

      Hex.Mix.update_config([key: "other", foo: :bar])
      assert Hex.Mix.read_config == [key: "other", foo: :bar]
    end
  end

  test "from mixlock" do
    lock = [ ex_doc: { :package, "0.1.0" },
             postgrex: { :package, "0.2.1" } ]
    assert Hex.Mix.from_lock(lock) == %{"ex_doc" => "0.1.0", "postgrex" => "0.2.1"}
  end
end
