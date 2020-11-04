defmodule Client do

  require Logger

  use GenServer
  #use GenServer, restart: :temporary

  @name __MODULE__
  
  @sec 1_000
  @min 60 * @sec
  
  #@call_timeout :infinity
  @call_timeout 5 * @sec

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    {:ok, %{}}
  end

  def start(args, bs_node) do
    GenServer.call(@name, {:start, args, bs_node}, @call_timeout)
  end


  def handle_call({:start, args, bs_node}, _from, state) do
    IO.puts "Hello from Client #{inspect bs_node} "

    Application.put_env(:mldht, :port, 0)
    Application.put_env(:mldht, :bootstrap_nodes, bs_node)

    {:ok, pid} = MlDHT.Supervisor.start_link(args)
    {:reply, pid, state}
  end

end
