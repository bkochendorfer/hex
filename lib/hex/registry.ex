defmodule Hex.Registry do
  @registry_tid :registry_tid
  @version      1

  def start(opts \\ []) do
    path = opts[:registry_path] || path()

    case :ets.file2tab(String.to_char_list!(path)) do
      { :ok, tid } ->
        :application.set_env(:hex, @registry_tid, tid)

        case :ets.lookup(tid, :"$$version$$") do
          [{ :"$$version$$", @version }] ->
            :ok
          _ ->
            raise Hex.Error, message: "The registry file version is newer than what is supported. " <>
              "Please update hex."
        end

      { :error, _reason } ->
        raise Hex.Error, message: "Failed to open hex registry file. " <>
          "Did you fetch it with 'mix hex.update'?"
    end
  end

  def stop do
    { :ok, tid } = :application.get_env(:hex, @registry_tid)
    :ets.delete(tid)
    :ok
  end

  def path do
    Path.join(Mix.Utils.mix_home, "hex.ets")
  end

  def stat do
    fun = fn
      { { _, _ }, _, _, _, _ }, { packages, releases } ->
        { packages, releases + 1 }
      { _, _, _, _, _ }, { packages, releases } ->
        { packages + 1, releases }
      _, acc ->
        acc
    end

    { :ok, tid } = :application.get_env(:hex, @registry_tid)
    :ets.foldl(fun, { 0, 0 }, tid)
  end

  def package_exists?(package) do
    !! get_versions(package)
  end

  def get_versions(package) do
    { :ok, tid } = :application.get_env(:hex, @registry_tid)
    case :ets.lookup(tid, package) do
      [] -> nil
      [{ ^package, versions }] -> versions
    end
  end

  def get_release(package, version) do
    { :ok, tid } = :application.get_env(:hex, @registry_tid)
    case :ets.lookup(tid, { package, version }) do
      [] -> nil
      [release] -> release
    end
  end

  def version_from_ref(package, url, ref) do
    { :ok, tid } = :application.get_env(:hex, @registry_tid)
    match = { { package, :"$1" }, :_, url, ref }

    case :ets.match(tid, match) do
      [] -> :error
      [[version]] -> { :ok, version }
    end
  end
end
