defmodule Top5Web.HomeController do
  use Top5Web, :controller

  def index(conn, _params) do
    conn
    |> put_flash( :info, "Login using your Username / Password")
    |> render("index.html")
  end

end
