defmodule Top5.Repo.Migrations.UserTableAddHasManyRelationToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :user_id, references(:users)
    end
  end
end
