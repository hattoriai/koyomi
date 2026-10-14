defmodule Koyomi.MessagesTest do
  use ExUnit.Case, async: false

  alias Koyomi.Messages

  doctest Messages

  test "every language has every key, with the same placeholders" do
    english = Messages.for_locale("en")

    for language <- Messages.languages() do
      words = Messages.for_locale(language)
      assert Map.keys(words) == Map.keys(english)

      for {key, text} <- english do
        placeholders = fn text ->
          ~r/\{\w+\}/ |> Regex.scan(text) |> List.flatten() |> Enum.sort()
        end

        assert placeholders.(words[key]) == placeholders.(text), "#{language} #{key}"
      end
    end
  end

  test "config words, by language and by locale" do
    Application.put_env(:koyomi, :messages, %{
      "pt" => %{"today" => "Hoje mesmo"},
      "pt-BR" => %{"clear" => "Apagar"}
    })

    on_exit(fn -> Application.delete_env(:koyomi, :messages) end)

    assert Messages.for_locale("pt-PT")["today"] == "Hoje mesmo"
    assert Messages.for_locale("pt-BR")["clear"] == "Apagar"
    assert Messages.for_locale("pt-PT")["clear"] != "Apagar"
  end

  test "an unknown key raises" do
    assert_raise ArgumentError, ~r/unknown message keys \["tday"\]/, fn ->
      Messages.for_locale("en", %{tday: "x"})
    end
  end
end
