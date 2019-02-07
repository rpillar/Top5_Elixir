defmodule Top5.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset


  schema "tasks" do
    field :deadline, :naive_datetime
    field :in_backlog, :boolean, default: false
    field :priority, :integer
    field :status, :string
    field :task_description, :string
    field :taskname, :string
    belongs_to :user, Top5.Accounts.User
    has_many :notes, Top5.Tasks.Note

    timestamps()
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:taskname, :task_description, :status, :in_backlog, :deadline, :priority])
    |> validate_required([:taskname, :task_description, :status, :in_backlog, :deadline, :priority])
  end
end
