defmodule Top5Web.RegisterController do
  use Top5Web, :controller

  def index(conn, _params) do
    conn
    |> put_flash( :info, "Enter all details to sign-up for this service.")
    |> render("index.html")
  end

end
