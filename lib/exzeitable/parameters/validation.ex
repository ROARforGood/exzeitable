defmodule Exzeitable.Parameters.Validation do
  @moduledoc "Using these instead of Keyword.fetch! to provide nice easily resolvable errors."

  alias Exzeitable.Parameters.ParameterError

  @doc "If you have parent then you need belongs_to, and vice versa."
  @spec paired_options(map) :: map | nil
  def paired_options(%{"parent" => nil, "belongs_to" => nil} = session) do
    session
  end

  def paired_options(%{"parent" => nil}) do
    raise ParameterError,
      message:
        "[:parent] record needs to be defined if belongs_to is defined, i.e. Repo.find(site.id)"
  end

  def paired_options(%{"belongs_to" => nil}) do
    raise ParameterError,
      message: "[:belongs_to] needs to be defined if parent is defined, i.e. :site"
  end

  def paired_options(session) do
    session
  end

  @doc "If you have a record_source then query is optional, otherwise required."
  @spec has_query_source(map) :: map | nil
  def has_query_source(%{"record_source" => record_source, "query" => query} = session) do
    case {record_source, query} do
      {nil, nil} ->
        raise ParameterError,
          message: "[:query] needs to be defined if [:record_source] is not"

      _ ->
        session
    end
  end
end
