defmodule Hex.Tar do
  @supported ["1", "2"]
  @version "2"
  @required_files ['VERSION', 'CHECKSUM', 'metadata.exs', 'contents.tar.gz']

  def create(meta, files) do
    contents_path = "#{meta[:app]}-#{meta[:version]}-contents.tar.gz"
    path = "#{meta[:app]}-#{meta[:version]}.tar"

    files =
      Enum.map(files, fn
        { name, bin } -> { String.to_char_list(name), bin }
        name -> String.to_char_list(name)
      end)

    :ok = :erl_tar.create(contents_path, files, [:compressed, :cooked])
    contents = File.read!(contents_path)

    meta_string = Hex.Util.safe_serialize_elixir(meta)
    blob = @version <> meta_string <> contents
    checksum = :crypto.hash(:sha256, blob) |> Hex.Util.hexify

    files = [
      { 'VERSION', @version},
      { 'CHECKSUM', checksum },
      { 'metadata.exs', meta_string },
      { 'contents.tar.gz', contents } ]
    :ok = :erl_tar.create(path, files, [:cooked])

    tar = File.read!(path)
    File.rm!(contents_path)
    File.rm!(path)
    tar
  end

  def unpack(path, dest) do
    case :erl_tar.extract(path, [:memory]) do
      { :ok, files } ->
        files = Enum.into(files, %{})
        check_files(files, path)
        check_version(files['VERSION'], path)
        checksum(files, path)
        extract_contents(files['contents.tar.gz'], dest, path)

      :ok ->
        raise Mix.Error, message: "Unpacking #{path} failed: tarball empty"

      { :error, reason } ->
        raise Mix.Error, message: "Unpacking #{path} failed: #{inspect reason}"
    end
  end

  defp check_files(files, path) do
    diff = @required_files -- Dict.keys(files)
    if diff != [] do
      diff = Enum.join(diff, ", ")
      raise Mix.Error, message: "Missing files #{diff} in #{path}"
    end
  end

  defp check_version(version, path) do
    unless version in @supported do
      raise Mix.Error,
        message: "Unsupported tarball version #{version} in #{path}. " <>
                 "Try updating Hex with `mix local.hex`."
    end
  end

  defp checksum(files, path) do
    blob = files['VERSION'] <> files['metadata.exs'] <> files['contents.tar.gz']
    hash = version_hash(files['VERSION'])
    if :crypto.hash(hash, blob) != Hex.Util.dehexify(files['CHECKSUM']) do
      raise Mix.Error, message: "Checksum wrong in #{path}"
    end
  end

  defp extract_contents(file, dest, path) do
    case :erl_tar.extract({ :binary, file }, [:compressed, cwd: dest]) do
      :ok ->
        :ok
      { :error, reason } ->
        raise Mix.Error, message: "Unpacking #{path}/contents.tar.gz failed: #{inspect reason}"
    end
  end

  defp version_hash("1"), do: :md5
  defp version_hash("2"), do: :sha256
end
