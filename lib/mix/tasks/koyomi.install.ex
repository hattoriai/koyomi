defmodule Mix.Tasks.Koyomi.Install do
  @shortdoc "Adds the Koyomi hook and style sheet to a Phoenix app"

  @moduledoc """
  Sets up Koyomi in a Phoenix application.

      $ mix koyomi.install
      $ mix koyomi.install --dry-run

  The task edits two files:

    * `assets/js/app.js` - adds `import { Koyomi } from "koyomi"` and puts
      `Koyomi` in the `hooks` of the `LiveSocket`. When it cannot find the
      `new LiveSocket(...)` call, or its hooks are not an object or a
      variable, it changes nothing and prints the lines to add.
    * `assets/css/app.css` - adds
      `@import "../../deps/koyomi/priv/static/koyomi.css";`, and the Sumi
      theme import as a comment. The imports follow the deps directory of
      the project (`Mix.Project.deps_path/0`) when it is not `deps/`, as in
      an umbrella child or with `MIX_DEPS_PATH`. For a path dependency
      (`{:koyomi, path: "../koyomi"}`), which Mix does not copy into
      `deps/`, the imports point at the dependency's directory instead.

  Then it prints the esbuild note (the app's esbuild must resolve `koyomi`
  through `NODE_PATH`: from `deps/`, or, for a path dependency, from the
  directory that holds it) and how to start the pickers on a page without
  LiveView.

  The task is idempotent: it does not add what a file already has, and when
  there is nothing to add it says so.

  ## Options

    * `--dry-run` - prints the changes as a diff and writes nothing.
  """

  use Mix.Task

  alias Koyomi.Install.Edits

  @js "assets/js/app.js"
  @css "assets/css/app.css"
  @config "config/config.exs"

  @impl Mix.Task
  def run(argv) do
    deps_path = Mix.Project.deps_path()
    install(argv, package_path(Mix.Project.deps_paths(), deps_path), deps_path)
  end

  @doc false
  # The task, with the directory of the Koyomi package and the deps
  # directory of the project given.
  @spec install([String.t()], Path.t(), Path.t()) :: :ok
  def install(argv, package, deps_path \\ "deps") do
    {opts, _args} = OptionParser.parse!(argv, strict: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)

    css_dir = Edits.relative(package, Path.dirname(@css))

    results = [
      edit(@js, &Edits.app_js/1, Edits.app_js_manual(), dry_run?),
      edit(@css, &Edits.app_css(&1, css_dir), Edits.app_css_manual(css_dir), dry_run?)
    ]

    if Enum.all?(results, &(&1 == :unchanged)) do
      Mix.shell().info("Koyomi is already installed. Nothing changed.")
    else
      notes(package, deps_path)
    end
  end

  @doc false
  # Where the Koyomi package is, from `Mix.Project.deps_paths/0`: koyomi in
  # the deps directory (`Mix.Project.deps_path/0`, which an umbrella child or
  # MIX_DEPS_PATH moves away from deps/), or the directory of a path
  # dependency (`{:koyomi, path: "../koyomi"}`), which Mix does not copy there.
  @spec package_path(%{optional(atom()) => Path.t()}, Path.t()) :: Path.t()
  def package_path(deps_paths, deps_path \\ "deps") do
    case deps_paths[:koyomi] do
      nil -> Path.expand(Path.join(deps_path, "koyomi"))
      path -> Path.expand(path)
    end
  end

  defp edit(path, fun, manual, dry_run?) do
    case File.read(path) do
      {:ok, source} ->
        apply_edit(path, source, fun.(source), dry_run?)

      {:error, _reason} ->
        Mix.shell().info([:yellow, "* skipping ", :reset, path, " (not found)"])
        Mix.shell().info(indent(manual))
        :manual
    end
  end

  defp apply_edit(path, _source, :unchanged, _dry_run?) do
    Mix.shell().info([:green, "* unchanged ", :reset, path, " (Koyomi is already there)"])
    :unchanged
  end

  defp apply_edit(path, _source, {:manual, text}, _dry_run?) do
    Mix.shell().info([:yellow, "* skipping ", :reset, path, " (add the lines below by hand)"])
    Mix.shell().info(indent(text))
    :manual
  end

  defp apply_edit(path, source, {:changed, new}, true) do
    Mix.shell().info([:cyan, "* would update ", :reset, path])
    Mix.shell().info(Edits.diff(path, source, new))
    :changed
  end

  defp apply_edit(path, source, {:changed, new}, false) do
    File.write!(path, new)
    Mix.shell().info([:green, "* updating ", :reset, path])
    Mix.shell().info(Edits.diff(path, source, new))
    :changed
  end

  defp notes(package, deps_path) do
    config_source =
      case File.read(@config) do
        {:ok, source} -> source
        {:error, _reason} -> ""
      end

    Mix.shell().info("""

    #{esbuild_note(config_source, package, deps_path)}

    For the Sumi theme, remove the comment marks around the koyomi-sumi.css
    import in assets/css/app.css.

    On a page without LiveView, the hook does not run. Import mountKoyomi
    in the page's script and call it after the page loads:

        import { mountKoyomi } from "koyomi"

        window.addEventListener("DOMContentLoaded", () => mountKoyomi())
    """)
  end

  defp esbuild_note(config_source, package, deps_path) do
    if Path.dirname(package) == Path.expand(deps_path) do
      deps = Edits.relative(deps_path, ".")
      from_config = Edits.relative(deps_path, "config")

      resolves? =
        if deps == "deps",
          do: Edits.node_path?(config_source),
          else: Edits.node_path?(config_source, from_config)

      if resolves? do
        "Your esbuild config sets NODE_PATH to #{deps}/, so `import { Koyomi } from \"koyomi\"` resolves."
      else
        """
        The esbuild profile of your app must resolve `koyomi` from #{deps}/. Give it
        NODE_PATH=#{deps} in config/config.exs:

            env: %{"NODE_PATH" => [Path.expand("#{from_config}", __DIR__), Mix.Project.build_path()]}\
        """
      end
    else
      parent = Edits.relative(Path.dirname(package), "config")

      if Edits.node_path?(config_source, parent) do
        "Your esbuild config has the directory of the Koyomi path dependency in NODE_PATH, so `import { Koyomi } from \"koyomi\"` resolves."
      else
        """
        Koyomi is a path dependency (#{Edits.relative(package, ".")}), so it is not in deps/.
        The esbuild profile of your app finds `koyomi` through NODE_PATH: add the
        directory that holds it to the NODE_PATH in config/config.exs:

            env: %{
              "NODE_PATH" => [
                Path.expand("../deps", __DIR__),
                Path.expand("#{parent}", __DIR__),
                Mix.Project.build_path()
              ]
            }\
        """
      end
    end
  end

  defp indent(text) do
    text
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> "    " <> line
    end)
  end
end
