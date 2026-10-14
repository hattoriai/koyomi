defmodule Mix.Tasks.Koyomi.ReleaseCheck do
  @shortdoc "Checks that priv/static holds the four bundle files and nothing else"

  @moduledoc """
  Checks the built files before a release of Koyomi.

      $ mix koyomi.release_check

  This task is for work on Koyomi itself; the `release` alias runs it
  after `mix koyomi.build` and before `mix hex.publish`. In any project
  but Koyomi, it stops with an error. It fails when:

    * one of the four bundle files (`koyomi.esm.js`, `koyomi.cjs.js`,
      `koyomi.css` and `koyomi-sumi.css`) is missing from `priv/static`,
      or is empty (the empty files that CI makes are not a build);
    * `priv/static` holds any other file or directory;
    * the `version` of `package.json` is not the version of `mix.exs`.
  """

  use Mix.Task

  @static "priv/static"
  @files ~w(koyomi.esm.js koyomi.cjs.js koyomi.css koyomi-sumi.css)

  @impl Mix.Task
  def run(_args) do
    config = Mix.Project.config()
    ensure_koyomi!(config)
    version = config[:version]

    case check(@static, "package.json", version) do
      :ok ->
        Mix.shell().info(
          "#{@static} holds the four bundle files, and nothing else, and package.json has version #{version}"
        )

      {:error, problems} ->
        Mix.raise("""
        Koyomi is not ready for a release:

        #{Enum.map_join(problems, "\n", &("  * " <> &1))}

        Build with `mix koyomi.build` (it empties #{@static} first); keep the \
        version of package.json equal to the version of mix.exs.\
        """)
    end
  end

  @doc false
  @spec ensure_koyomi!(keyword()) :: :ok
  def ensure_koyomi!(config) do
    if config[:app] == :koyomi do
      :ok
    else
      Mix.raise(
        "mix koyomi.release_check is for work on Koyomi itself; it checks the files of a Koyomi release"
      )
    end
  end

  @doc false
  @spec check(Path.t(), Path.t(), String.t()) :: :ok | {:error, [String.t()]}
  def check(static, package_json, version) do
    entries =
      case File.ls(static) do
        {:ok, entries} -> entries
        {:error, _reason} -> []
      end

    problems =
      Enum.flat_map(@files, &bundle_problems(static, &1, entries)) ++
        Enum.map(Enum.sort(entries -- @files), &"#{static}/#{&1} is not a bundle file") ++
        version_problems(package_json, version)

    if problems == [], do: :ok, else: {:error, problems}
  end

  defp bundle_problems(static, file, entries) do
    path = Path.join(static, file)

    cond do
      file not in entries -> ["#{path} is missing"]
      not File.regular?(path) -> ["#{path} is not a file"]
      File.stat!(path).size == 0 -> ["#{path} is empty"]
      true -> []
    end
  end

  defp version_problems(package_json, version) do
    with {:ok, source} <- File.read(package_json),
         {:ok, %{"version" => ^version}} <- JSON.decode(source) do
      []
    else
      _other -> ["the version of #{package_json} is not #{version}"]
    end
  end
end
