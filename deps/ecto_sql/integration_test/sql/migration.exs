defmodule Ecto.Integration.MigrationTest do
  use ExUnit.Case, async: true

  alias Ecto.Integration.PoolRepo

  defmodule CreateMigration do
    use Ecto.Migration

    @table table(:create_table_migration)
    @index index(:create_table_migration, [:value], unique: true)

    def up do
      create @table do
        add :value, :integer
      end
      create @index
    end

    def down do
      drop @index
      drop @table
    end
  end

  defmodule AddColumnMigration do
    use Ecto.Migration

    def up do
      create table(:add_col_migration) do
        add :value, :integer
      end

      alter table(:add_col_migration) do
        add :to_be_added, :integer
      end

      execute "INSERT INTO add_col_migration (value, to_be_added) VALUES (1, 2)"
    end

    def down do
      drop table(:add_col_migration)
    end
  end

  defmodule AlterColumnMigration do
    use Ecto.Migration

    def up do
      create table(:alter_col_migration) do
        add :from_null_to_not_null, :integer
        add :from_not_null_to_null, :integer, null: false

        add :from_default_to_no_default, :integer, default: 0
        add :from_no_default_to_default, :integer
      end

      alter table(:alter_col_migration) do
        modify :from_null_to_not_null, :string, null: false
        modify :from_not_null_to_null, :string, null: true

        modify :from_default_to_no_default, :integer, default: nil
        modify :from_no_default_to_default, :integer, default: 0
      end

      execute "INSERT INTO alter_col_migration (from_null_to_not_null) VALUES ('foo')"
    end

    def down do
      drop table(:alter_col_migration)
    end
  end

  defmodule AlterColumnFromMigration do
    use Ecto.Migration

    def change do
      create table(:modify_from_authors, primary_key: false) do
        add :id, :integer, primary_key: true
      end
      create table(:modify_from_posts) do
        add :author_id, references(:modify_from_authors, type: :integer)
      end

      if direction() == :up do
        flush()
        PoolRepo.insert_all "modify_from_authors", [[id: 1]]
        PoolRepo.insert_all "modify_from_posts", [[author_id: 1]]
      end

      alter table(:modify_from_posts) do
        # remove the constraints modify_from_posts_author_id_fkey
        modify :author_id, :integer, from: references(:modify_from_authors, type: :integer)
      end
      alter table(:modify_from_authors) do
        modify :id, :bigint, from: :integer
      end
      alter table(:modify_from_posts) do
        # add the constraints modify_from_posts_author_id_fkey
        modify :author_id, references(:modify_from_authors, type: :bigint), from: :integer
      end
    end
  end

  defmodule AlterForeignKeyOnDeleteMigration do
    use Ecto.Migration

    def up do
      create table(:alter_fk_users)

      create table(:alter_fk_posts) do
        add :alter_fk_user_id, :id
      end

      alter table(:alter_fk_posts) do
        modify :alter_fk_user_id, references(:alter_fk_users, on_delete: :nilify_all)
      end

      execute "INSERT INTO alter_fk_users (id) VALUES ('1')"
      execute "INSERT INTO alter_fk_posts (id, alter_fk_user_id) VALUES ('1', '1')"
      execute "DELETE FROM alter_fk_users"
    end

    def down do
      drop table(:alter_fk_posts)
      drop table(:alter_fk_users)
    end
  end

  defmodule AlterForeignKeyOnUpdateMigration do
    use Ecto.Migration

    def up do
      create table(:alter_fk_users)

      create table(:alter_fk_posts) do
        add :alter_fk_user_id, :id
      end

      alter table(:alter_fk_posts) do
        modify :alter_fk_user_id, references(:alter_fk_users, on_update: :update_all)
      end

      execute "INSERT INTO alter_fk_users (id) VALUES ('1')"
      execute "INSERT INTO alter_fk_posts (id, alter_fk_user_id) VALUES ('1', '1')"
      execute "UPDATE alter_fk_users SET id = '2'"
    end

    def down do
      drop table(:alter_fk_posts)
      drop table(:alter_fk_users)
    end
  end

  defmodule DropColumnMigration do
    use Ecto.Migration

    def up do
      create table(:drop_col_migration) do
        add :value, :integer
        add :to_be_removed, :integer
      end

      execute "INSERT INTO drop_col_migration (value, to_be_removed) VALUES (1, 2)"

      alter table(:drop_col_migration) do
        remove :to_be_removed
      end
    end

    def down do
      drop table(:drop_col_migration)
    end
  end

  defmodule RenameColumnMigration do
    use Ecto.Migration

    def up do
      create table(:rename_col_migration) do
        add :to_be_renamed, :integer
      end

      rename table(:rename_col_migration), :to_be_renamed, to: :was_renamed

      execute "INSERT INTO rename_col_migration (was_renamed) VALUES (1)"
    end

    def down do
      drop table(:rename_col_migration)
    end
  end

  defmodule OnDeleteMigration do
    use Ecto.Migration

    def up do
      create table(:parent1)
      create table(:parent2)

      create table(:ref_migration) do
        add :parent1, references(:parent1, on_delete: :nilify_all)
      end

      alter table(:ref_migration) do
        add :parent2, references(:parent2, on_delete: :delete_all)
      end
    end

    def down do
      drop table(:ref_migration)
      drop table(:parent1)
      drop table(:parent2)
    end
  end

  defmodule ReferencesRollbackMigration do
    use Ecto.Migration

    def change do
      create table(:parent) do
        add :name, :string
      end

      create table(:child) do
        add :parent_id, references(:parent)
      end
    end
  end

  defmodule RenameMigration do
    use Ecto.Migration

    @table_current table(:posts_migration)
    @table_new table(:new_posts_migration)

    def up do
      create @table_current
      rename @table_current, to: @table_new
    end

    def down do
      drop @table_new
    end
  end

  defmodule PrefixMigration do
    use Ecto.Migration

    @prefix "ecto_prefix_test"

    def up do
      execute PoolRepo.create_prefix(@prefix)
      create table(:first, prefix: @prefix)
      create table(:second, prefix: @prefix) do
        add :first_id, references(:first)
      end
    end

    def down do
      drop table(:second, prefix: @prefix)
      drop table(:first, prefix: @prefix)
      execute PoolRepo.drop_prefix(@prefix)
    end
  end

  defmodule NoSQLMigration do
    use Ecto.Migration

    def up do
      create table(:collection, options: [capped: true])
      execute create: "collection"
    end
  end

  defmodule Parent do
    use Ecto.Schema

    schema "parent" do
    end
  end

  defmodule NoErrorTableMigration do
    use Ecto.Migration

    def change do
      create_if_not_exists table(:existing) do
        add :name, :string
      end

      create_if_not_exists table(:existing) do
        add :name, :string
      end

      create_if_not_exists table(:existing)

      drop_if_exists table(:existing)
      drop_if_exists table(:existing)
    end
  end

  defmodule NoErrorIndexMigration do
    use Ecto.Migration

    def change do
      create_if_not_exists index(:posts, [:title])
      create_if_not_exists index(:posts, [:title])
      drop_if_exists index(:posts, [:title])
      drop_if_exists index(:posts, [:title])
    end
  end

  defmodule InferredDropIndexMigration do
    use Ecto.Migration

    def change do
      create index(:posts, [:title])
    end
  end

  defmodule AlterPrimaryKeyMigration do
    use Ecto.Migration

    def change do
      create table(:no_pk, primary_key: false) do
        add :dummy, :string
      end
      alter table(:no_pk) do
        add :id, :serial, primary_key: true
      end
    end
  end

  import Ecto.Query, only: [from: 2]
  import Ecto.Migrator, only: [up: 4, down: 4]

  # Avoid migration out of order warnings
  @moduletag :capture_log
  @base_migration 1_000_000

  setup do
    {:ok, migration_number: System.unique_integer([:positive]) + @base_migration}
  end

  test "create and drop table and indexes", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, CreateMigration, log: false)
    assert :ok == down(PoolRepo, num, CreateMigration, log: false)
  end

  test "correctly infers how to drop index", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, InferredDropIndexMigration, log: false)
    assert :ok == down(PoolRepo, num, InferredDropIndexMigration, log: false)
  end

  test "supports references", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, OnDeleteMigration, log: false)

    parent1 = PoolRepo.insert! Ecto.put_meta(%Parent{}, source: "parent1")
    parent2 = PoolRepo.insert! Ecto.put_meta(%Parent{}, source: "parent2")

    writer = "INSERT INTO ref_migration (parent1, parent2) VALUES (#{parent1.id}, #{parent2.id})"
    PoolRepo.query!(writer)

    reader = from r in "ref_migration", select: {r.parent1, r.parent2}
    assert PoolRepo.all(reader) == [{parent1.id, parent2.id}]

    PoolRepo.delete!(parent1)
    assert PoolRepo.all(reader) == [{nil, parent2.id}]

    PoolRepo.delete!(parent2)
    assert PoolRepo.all(reader) == []

    assert :ok == down(PoolRepo, num, OnDeleteMigration, log: false)
  end

  test "rolls back references in change/1", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, ReferencesRollbackMigration, log: false)
    assert :ok == down(PoolRepo, num, ReferencesRollbackMigration, log: false)
  end

  test "create table if not exists and drop table if exists does not raise on failure", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, NoErrorTableMigration, log: false)
  end

  @tag :create_index_if_not_exists
  test "create index if not exists and drop index if exists does not raise on failure", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, NoErrorIndexMigration, log: false)
  end

  test "raises on NoSQL migrations", %{migration_number: num} do
    assert_raise ArgumentError, ~r"does not support keyword lists in :options", fn ->
      up(PoolRepo, num, NoSQLMigration, log: false)
    end
  end

  @tag :add_column
  test "add column", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AddColumnMigration, log: false)
    assert [2] == PoolRepo.all from p in "add_col_migration", select: p.to_be_added
    :ok = down(PoolRepo, num, AddColumnMigration, log: false)
  end

  @tag :modify_column
  test "modify column", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AlterColumnMigration, log: false)

    assert ["foo"] ==
           PoolRepo.all from p in "alter_col_migration", select: p.from_null_to_not_null
    assert [nil] ==
           PoolRepo.all from p in "alter_col_migration", select: p.from_not_null_to_null
    assert [nil] ==
           PoolRepo.all from p in "alter_col_migration", select: p.from_default_to_no_default
    assert [0] ==
           PoolRepo.all from p in "alter_col_migration", select: p.from_no_default_to_default

    query = "INSERT INTO alter_col_migration (from_not_null_to_null) VALUES ('foo')"
    assert catch_error(PoolRepo.query!(query))

    :ok = down(PoolRepo, num, AlterColumnMigration, log: false)
  end

  @tag :modify_column_with_from
  test "modify column with from", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AlterColumnFromMigration, log: false)

    assert [1] ==
           PoolRepo.all from p in "modify_from_posts", select: p.author_id

    :ok = down(PoolRepo, num, AlterColumnFromMigration, log: false)
  end

  @tag :modify_foreign_key_on_delete
  test "modify foreign key's on_delete constraint", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AlterForeignKeyOnDeleteMigration, log: false)
    assert [nil] == PoolRepo.all from p in "alter_fk_posts", select: p.alter_fk_user_id
    :ok = down(PoolRepo, num, AlterForeignKeyOnDeleteMigration, log: false)
  end

  @tag :modify_foreign_key_on_update
  test "modify foreign key's on_update constraint", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AlterForeignKeyOnUpdateMigration, log: false)
    assert [2] == PoolRepo.all from p in "alter_fk_posts", select: p.alter_fk_user_id
    :ok = down(PoolRepo, num, AlterForeignKeyOnUpdateMigration, log: false)
  end

  @tag :remove_column
  test "remove column", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, DropColumnMigration, log: false)
    assert catch_error(PoolRepo.all from p in "drop_col_migration", select: p.to_be_removed)
    :ok = down(PoolRepo, num, DropColumnMigration, log: false)
  end

  @tag :rename_column
  test "rename column", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, RenameColumnMigration, log: false)
    assert [1] == PoolRepo.all from p in "rename_col_migration", select: p.was_renamed
    :ok = down(PoolRepo, num, RenameColumnMigration, log: false)
  end

  @tag :rename_table
  test "rename table", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, RenameMigration, log: false)
    assert :ok == down(PoolRepo, num, RenameMigration, log: false)
  end

  @tag :prefix
  test "prefix", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, PrefixMigration, log: false)
    assert :ok == down(PoolRepo, num, PrefixMigration, log: false)
  end

  @tag :alter_primary_key
  test "alter primary key", %{migration_number: num} do
    assert :ok == up(PoolRepo, num, AlterPrimaryKeyMigration, log: false)
    assert :ok == down(PoolRepo, num, AlterPrimaryKeyMigration, log: false)
  end
end
