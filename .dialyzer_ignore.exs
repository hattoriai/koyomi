# LazyHTML is a dependency of an app's tests (Phoenix.LiveViewTest needs
# it), not of Koyomi: Koyomi.Test calls it, and it is not in the PLT.
[
  {"lib/koyomi/test.ex", :unknown_function}
]
