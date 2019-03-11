defmodule Top5Web.TaskController do
    use Top5Web, :controller

    alias Top5.Accounts
    alias Top5.Tasks
    alias Top5Web.Router.Helpers

    plug :check_auth
  
    def index(conn, _params) do
      tasks = Tasks.list_tasks
      conn
      |> render("index.html", tasks: tasks)
    end

    def logout(conn, _params) do
        conn
        |> delete_session(:current_user_id)
        |> redirect(to: Helpers.home_path(conn, :index))
    end

    defp check_auth(conn, _params) do
        if user_id = get_session(conn, :current_user_id) do
            current_user = Accounts.get_user!(user_id)
            conn
            |> assign(:current_user, current_user)
        else
            conn
            |> clear_flash
            |> put_flash( :error, "Error : You need to login to access the service." )
            |> redirect(to: Helpers.home_path(conn, :index))
        end
    end

  end