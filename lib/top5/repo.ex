defmodule Top5.Repo do
  use Ecto.Repo,
    otp_app: :top5,
    adapter: Ecto.Adapters.Postgres
end
