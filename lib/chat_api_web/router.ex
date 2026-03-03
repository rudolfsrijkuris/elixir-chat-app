defmodule ChatApiWeb.Router do
  use ChatApiWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :fetch_query_params
    plug :protect_from_forgery
    plug :put_root_layout, html: {ChatApiWeb.Layouts, :root}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ChatApiWeb do
    pipe_through :api

    post "/users", UserController, :create
    post "/messages", MessageController, :create
    get "/conversations", MessageController, :conversation
  end

  scope "/", ChatApiWeb do
    pipe_through :browser

    post "/login", PageController, :login
    # Fallback when message form does a native POST (e.g. before LiveView connects)
    post "/chat", PageController, :chat_redirect

    live_session :default do
      live "/", HomeLive, :index
      live "/chat", ChatLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chat_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ChatApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
