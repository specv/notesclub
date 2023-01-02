defmodule Notesclub.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Notesclub.Repo

  alias Notesclub.Accounts.User
  alias Notesclub.Workers.UserSyncWorker

  require Logger
  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  @spec list_users :: [%User{}]
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_user!(integer) :: %User{}
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  # @spec create_user(map) :: {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  def create_user(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      username: nil,
      name: nil,
      twitter_username: nil,
      avatar_url: nil})
      |> create_user_and_enqueue_sync_if_necessary()

    # %User{}
    # |> User.changeset(attrs)
    # |> Repo.insert()
  end

  defp create_user_and_enqueue_sync_if_necessary(%{name: nil} = attrs), do: create_user_and_enqueue_sync(attrs)

  defp create_user_and_enqueue_sync_if_necessary(%{twitter_username: nil} = attrs), do: create_user_and_enqueue_sync(attrs)


  defp create_user_and_enqueue_sync_if_necessary(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  defp create_user_and_enqueue_sync(attrs) do
    changeset = User.changeset(%User{}, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, changeset)
    |> Ecto.Multi.insert(
      :user_default_branch_worker,
      fn %{user: %User{id: user_id}} ->
        UserSyncWorker.new(%{user_id: user_id})
      end
    )
    |> Repo.transaction()
    |> case do
      _ -> IO.inspect("Finish")
    end

    # |> case do
    #   _ -> IO.inspect("got to end")
    #   # {:ok, %{repo: repo}} ->
    #   #   {:ok, repo}

    #   # {:error, :repo, changeset, _} ->
    #   #   {:error, changeset}

    #   # {:error, :repo_default_branch_worker, changeset, _} ->
    #   #   Logger.error(
    #   #     "create_repo failed in repo_default_branch_worker. This should never happen. attrs: #{inspect(attrs)}"
    #   #   )

    #   #   {:error, changeset}
    # end

  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_user(%User{}, map) :: {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_user(%User{}) :: {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """

  @spec change_user(%User{}, map) :: %Ecto.Changeset{}
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Finds a user by username
  Returns `%User{}` or nil

  ## Examples

      iex> get_by_username(username)
      %User{}

      iex> get_by_username(non_existent_username)
      nil

  """
  def get_by_username(nil), do: nil

  @spec get_by_username(binary) :: %User{} | nil
  def get_by_username(username) do
    Repo.get_by(User, username: username)
  end
end
