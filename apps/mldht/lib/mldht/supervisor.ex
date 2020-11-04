defmodule MlDHT.Supervisor do

  use Supervisor, restart: :temporary
  require Logger

 @moduledoc ~S"""
  Root Supervisor for MlDHT

  """

  @doc false
  # TODO: use Keyword.fetch!/2 to enforce the :node_id option
  def start_link(opts) do
    if opts[:remote] do
      Logger.error "FOOOOOBARR REMOTE"
      :rpc.call(:bar@ubuntu, Supervisor, :start_link, [__MODULE__, {:ok, opts[:node_id], opts[:delay]}, opts])
      # Supervisor.start_link(__MODULE__, {:ok, opts[:node_id], opts[:delay]}, opts)
    else
      Supervisor.start_link(__MODULE__, {:ok, opts[:node_id], opts[:delay]}, opts)
    end

  end

  @impl true
  def init({:ok, node_id, delay}) do
    node_id_enc = node_id |> Base.encode16()

    children = [
      {DynamicSupervisor,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.RoutingTable.Supervisor),
       strategy: :one_for_one},

      {MlDHT.Search.Supervisor,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Search.Supervisor),
       strategy: :one_for_one},

      {MlDHT.Server.Worker,
       node_id: node_id,
       delay:   delay,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Worker)},

      {MlDHT.Server.Storage,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Storage)},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
