defmodule Top5.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :taskname, :string
      add :task_description, :string
      add :status, :string
      add :in_backlog, :boolean, default: false, null: false
      add :deadline, :naive_datetime
      add :priority, :integer

      timestamps()
    end

  end
end
