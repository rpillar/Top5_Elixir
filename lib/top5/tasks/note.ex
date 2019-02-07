defmodule Top5.Tasks.Note do
  use Ecto.Schema
  import Ecto.Changeset


  schema "notes" do
    field :note, :string
    belongs_to :task, Top5.Accounts.Task

    timestamps()
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:note])
    |> validate_required([:note])
  end
end
