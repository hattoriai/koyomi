defmodule Koyomi.Install.EditsTest do
  use ExUnit.Case, async: true

  alias Koyomi.Install.Edits

  # The parts of the files of a new Phoenix 1.8 app that the edits read.
  @app_js """
  // Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
  import "phoenix_html"
  // Establish Phoenix Socket and LiveView configuration.
  import {Socket} from "phoenix"
  import {LiveSocket} from "phoenix_live_view"
  import {hooks as colocatedHooks} from "phoenix-colocated/my_app"
  import topbar from "../vendor/topbar"

  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken},
    hooks: {...colocatedHooks},
  })

  // connect if there are any LiveViews on the page
  liveSocket.connect()
  """

  @app_css """
  /* See the Tailwind configuration guide for advanced usage
     https://tailwindcss.com/docs/configuration */

  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/my_app_web";

  /* This file is for your main application CSS */
  """

  @config_exs ~S"""
  import Config

  # Configure esbuild (the version is required)
  config :esbuild,
    version: "0.25.4",
    my_app: [
      args:
        ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
    ]

  import_config "#{config_env()}.exs"
  """

  defp fixture("app.js"), do: @app_js
  defp fixture("app.css"), do: @app_css
  defp fixture("config.exs"), do: @config_exs

  defp socket(options), do: ~s|const liveSocket = new LiveSocket("/live", Socket, #{options})\n|

  describe "app_js/1" do
    test "adds the import and the hook to the Phoenix 1.8 app.js" do
      source = fixture("app.js")
      assert {:changed, new} = Edits.app_js(source)

      assert new =~
               ~s(import topbar from "../vendor/topbar"\nimport { Koyomi } from "koyomi"\n)

      assert new =~ "  hooks: {...colocatedHooks, Koyomi},\n"
      assert Edits.app_js(new) == :unchanged

      # Only the two lines change.
      assert length(String.split(new, "\n")) == length(String.split(source, "\n")) + 1
    end

    test "keeps an import that is there" do
      source = ~s(import { Koyomi } from "koyomi"\n) <> socket("{hooks: {}}")
      assert {:changed, new} = Edits.app_js(source)
      assert new == ~s(import { Koyomi } from "koyomi"\n) <> socket("{hooks: {Koyomi}}")
    end

    test "adds a hooks key to options without one" do
      assert {:changed, new} = Edits.app_js(socket("{params: {_csrf_token: csrfToken}}"))
      assert new =~ socket("{hooks: {Koyomi}, params: {_csrf_token: csrfToken}}")

      assert {:changed, new} = Edits.app_js(socket("{}"))
      assert new =~ socket("{hooks: {Koyomi}}")

      assert {:changed, new} = Edits.app_js(socket("{\n  params: {_csrf_token: csrfToken}\n}"))
      assert new =~ socket("{\n  hooks: {Koyomi},\n  params: {_csrf_token: csrfToken}\n}")
    end

    test "adds to a hooks object on several lines" do
      assert {:changed, new} =
               Edits.app_js(socket("{\n  hooks: {\n    ...colocatedHooks,\n    Chart\n  },\n}"))

      assert new =~
               socket("{\n  hooks: {\n    ...colocatedHooks,\n    Chart,\n    Koyomi,\n  },\n}")

      assert Edits.app_js(new) == :unchanged
    end

    test "spreads a hooks variable" do
      source = "let Hooks = {}\n" <> socket("{hooks: Hooks, params: {}}")
      assert {:changed, new} = Edits.app_js(source)
      assert new =~ socket("{hooks: {...Hooks, Koyomi}, params: {}}")
      assert Edits.app_js(new) == :unchanged
    end

    test "leaves a hooks variable that already has Koyomi" do
      source =
        ~s(import { Koyomi } from "koyomi"\nlet Hooks = {}\nHooks.Koyomi = Koyomi\n) <>
          socket("{hooks: Hooks}")

      assert Edits.app_js(source) == :unchanged
    end

    test "adds the import after a last import on several lines" do
      source =
        ~s(import {Socket} from "phoenix"\nimport {\n  a,\n  b\n} from "x";\n\n) <>
          socket("{hooks: {}}")

      assert {:changed, new} = Edits.app_js(source)

      assert new =~
               ~s(import {\n  a,\n  b\n} from "x";\nimport { Koyomi } from "koyomi"\n\nconst liveSocket)

      assert Edits.app_js(new) == :unchanged
    end

    test "adds the import after an import that ends with a semicolon" do
      source = ~s(import "phoenix_html";\nimport {Socket} from "phoenix";\n) <> socket("{}")
      assert {:changed, new} = Edits.app_js(source)
      assert new =~ ~s(import {Socket} from "phoenix";\nimport { Koyomi } from "koyomi"\nconst)
    end

    test "puts the import at the top when there is no import" do
      assert {:changed, new} = Edits.app_js(socket("{}"))
      assert new == ~s(import { Koyomi } from "koyomi"\n) <> socket("{hooks: {Koyomi}}")
    end

    test "is not misled by an import in a comment or a string" do
      source = ~s(// import {x} from "y"\nconst s = "\\nimport z"\n) <> socket("{}")
      assert {:changed, new} = Edits.app_js(source)
      assert String.starts_with?(new, ~s(import { Koyomi } from "koyomi"\n// import))
    end

    test "sees an import of Koyomi from another path" do
      source = ~s(import {Koyomi} from "../../deps/koyomi"\n) <> socket("{}")
      assert {:changed, new} = Edits.app_js(source)
      assert new == ~s(import {Koyomi} from "../../deps/koyomi"\n) <> socket("{hooks: {Koyomi}}")
    end

    test "gives the lines to add for a quoted hooks key or the hooks shorthand" do
      for options <- [~s({"hooks": Hooks}), ~s({'hooks': {}}), "{params, hooks}", "{hooks}"] do
        assert {:manual, _text} = Edits.app_js(socket(options)), options
      end

      assert {:changed, new} = Edits.app_js(socket("{hooks: hooks}"))
      assert new =~ "hooks: {...hooks, Koyomi}"
      assert {:changed, _new} = Edits.app_js(socket(~s({params: {"hooks": 1}})))
    end

    test "is not misled by strings and comments" do
      source =
        ~s|// new LiveSocket("/live", Socket, {hooks: {Koyomi}})\n| <>
          socket(~s|{params: {note: "hooks: {x}"}, /* hooks: {} */ hooks: {...colocatedHooks}}|)

      assert {:changed, new} = Edits.app_js(source)
      assert new =~ ~s|hooks: {...colocatedHooks, Koyomi}}|
      assert new =~ ~s|"hooks: {x}"|
      assert new =~ ~s|// new LiveSocket("/live", Socket, {hooks: {Koyomi}})|
    end

    test "gives the lines to add when it cannot find the constructor" do
      for source <- [
            "console.log(1)\n",
            socket("options"),
            socket("{hooks: makeHooks()}"),
            ~s|// new LiveSocket("/live", Socket, {hooks: {}})\n|
          ] do
        assert {:manual, text} = Edits.app_js(source)
        assert text =~ ~s(import { Koyomi } from "koyomi")
        assert text =~ "hooks: {...colocatedHooks, Koyomi}"
      end

      source = ~s(import { Koyomi } from "koyomi"\n) <> socket("options")
      assert {:manual, text} = Edits.app_js(source)
      refute text =~ "Add the import"
    end
  end

  describe "app_css/1" do
    test "adds the imports after the last @import of the Phoenix 1.8 app.css" do
      source = fixture("app.css")
      assert {:changed, new} = Edits.app_css(source)

      assert new =~
               """
               @import "tailwindcss" source(none);
               @import "../../deps/koyomi/priv/static/koyomi.css";
               /* @import "../../deps/koyomi/priv/static/koyomi-sumi.css"; */
               @source "../css";
               """

      assert Edits.app_css(new) == :unchanged
    end

    test "adds only what is missing" do
      # A person who removed the Sumi line does not get it back.
      source = ~s(@import "../../deps/koyomi/priv/static/koyomi.css";\nbody {}\n)
      assert Edits.app_css(source) == :unchanged

      source = ~s(@import "../../deps/koyomi/priv/static/koyomi-sumi.css";\n)
      assert {:changed, new} = Edits.app_css(source)
      assert new =~ ~s(@import "../../deps/koyomi/priv/static/koyomi.css";)
      refute new =~ "/* @import"
    end

    test "puts the imports at the top when there is no @import" do
      assert {:changed, new} = Edits.app_css("body { margin: 0 }\n")
      assert String.starts_with?(new, ~s(@import "../../deps/koyomi/priv/static/koyomi.css";\n))
    end

    test "points the imports at the package directory it is given" do
      assert {:changed, new} = Edits.app_css(fixture("app.css"), "../../../koyomi")
      assert new =~ ~s(@import "../../../koyomi/priv/static/koyomi.css";\n)
      assert new =~ ~s(/* @import "../../../koyomi/priv/static/koyomi-sumi.css"; */\n)
      refute new =~ "deps/koyomi"
      assert Edits.app_css(new, "../../../koyomi") == :unchanged

      assert Edits.app_css_manual("../../../pickers") =~
               ~s(@import "../../../pickers/priv/static/koyomi.css";)
    end
  end

  test "relative/2 goes up where it must" do
    assert Edits.relative("/code/app/deps/koyomi", "/code/app/assets/css") == "../../deps/koyomi"
    assert Edits.relative("/code/koyomi", "/code/app/assets/css") == "../../../koyomi"
    assert Edits.relative("/code", "/code/app/config") == "../.."
  end

  test "node_path?/1" do
    assert Edits.node_path?(fixture("config.exs"))
    refute Edits.node_path?("config :esbuild, version: \"0.25.4\"\n")
  end

  test "node_path?/2 looks for the directory of a path dependency" do
    refute Edits.node_path?(fixture("config.exs"), "../..")

    source =
      ~S|env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Path.expand("../..", __DIR__)]}|

    assert Edits.node_path?(source, "../..")
    refute Edits.node_path?(source, "../../..")
  end

  test "diff/3 shows the changed lines with some context" do
    diff = Edits.diff("a.txt", "1\n2\n3\n4\n5\n6\n7\n", "1\n2\n3\nnew\n4\n5\n6\n7\n")

    assert diff == """
           --- a.txt
           +++ a.txt
             ...
             2
             3
           + new
             4
             5
             ...
           """
  end
end
