defmodule Top5Web.Router do
  use Top5Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/top5", Top5Web do
    pipe_through :browser

    get     "/",              HomeController,     :index
    post    "/",              HomeController,     :sign_in
    get     "/register",      RegisterController, :index
    post    "/register",      RegisterController, :create
    get     "/tasks",         TaskController,     :index
    get     "/tasks/logout",  TaskController,     :logout
  end

end
