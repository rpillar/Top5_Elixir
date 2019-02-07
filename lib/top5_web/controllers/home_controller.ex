defmodule Top5Web.HomeController do
  use Top5Web, :controller

  alias Top5.Accounts
  alias Top5Web.Router.Helpers

  def index(conn, _params) do
    conn
    |> put_flash( :info, "Login using your Username / Password")
    |> render("index.html")
  end

  def sign_in(conn, %{"session" => auth_params}) do

    case validate_signin(auth_params) do
      false ->
        conn
        |> clear_flash
        |> put_flash( :error, "Error - Username or Password is missing / incorrect" )
        |> render("index.html")
      true ->
        IO.puts "Valid signin data"
    end
    
    username = auth_params["username"]
    password = auth_params["password"]

    case authenticate_user(username, password) do
      {:error, :invalid_data} ->
        conn
        |> clear_flash
        |> put_flash( :error, "Error - Username or Password is missing / incorrect" )
        |> render("index.html")
      {:ok, user} ->
        conn
        |> clear_flash
        |> put_session(:current_user_id, user.id)
        |> put_flash( :info, "Signedin successfully" )
        |> redirect(to: Helpers.task_path(conn, :index))
    end

  end

  defp authenticate_user(username, password) do
    case user = Accounts.get_user_by_username(username) do
      nil ->
        {:error, :invalid_data}
      user ->
        if Pbkdf2.verify_pass(password, user.password) do
          {:ok, user}
        else
          {:error, :invalid_data}
        end
    end
  end

  defp validate_signin(params) do
    case ( Map.values(params) == ["",""] ) do 
      true ->
        false
      false ->
        true
    end
  end

end
