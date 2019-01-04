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

    get  "/",         HomeController,     :index
    #post "/login",    HomeController,     :login
    get  "/register", RegisterController, :index
  end

end
