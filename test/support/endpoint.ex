defmodule KoyomiTest.ErrorHTML do
  @moduledoc "Error pages for the test endpoint."

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule KoyomiTest.Router do
  @moduledoc "The router of the test endpoint."
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/" do
    pipe_through(:browser)
    live("/booking", KoyomiTest.BookingLive)
    live("/filters", KoyomiTest.FiltersLive)
  end
end

defmodule KoyomiTest.Endpoint do
  @moduledoc "A Phoenix endpoint for the `Koyomi.Live` and `Koyomi.Test` tests. It runs no server."
  use Phoenix.Endpoint, otp_app: :koyomi

  plug(Plug.Session, store: :cookie, key: "_koyomi_test", signing_salt: "koyomi-test")
  plug(KoyomiTest.Router)
end
