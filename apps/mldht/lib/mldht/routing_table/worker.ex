defmodule MlDHT.RoutingTable.Worker do
  @moduledoc false

  use GenServer
  #use GenServer, restart: :temporary

  require Logger
  require Bitwise

  alias MlDHT.RoutingTable.Node
  alias MlDHT.RoutingTable.Bucket
  alias MlDHT.RoutingTable.Distance

  alias MlDHT.Search.Worker, as: Search
  
  @sec 1_000
  @min 60 * @sec
  #@call_timeout :infinity
  @call_timeout 5 * @sec

  #############
  # Constants #
  #############

  ## 5 Minutes
  @review_time 5 * @min

  ## 5 minutes
  #@response_time 5 * @min
  @response_time 15 * @min

  ## 5 minutes
  @neighbourhood_maintenance_time 5 * @min

  ## 3 minutes
  @bucket_maintenance_time 3 * @min

  ## 15 minutes (in seconds)
  #@bucket_max_idle_time 15 * @min
  @bucket_max_idle_time 15 * @min

  ## 15 minute
  @dump_routing_table_time 5 * @min

  ##############
  # Public API #
  ##############

  def start_link(opts) do
    Logger.debug "Starting RoutingTable worker: #{inspect(opts)}"
    init_args = [node_id: opts[:node_id], rt_name: opts[:rt_name]]
    GenServer.start_link(__MODULE__,  init_args, opts)
  end

  def add(name, remote_node_id, address, socket) do
    GenServer.cast(name, {:add, remote_node_id, address, socket})
  end

  def size(name) do
    GenServer.call(name, :size, @call_timeout)
  end

  def cache_size(name) do
    GenServer.call(name, :cache_size, @call_timeout)
  end

  def update_bucket(name, bucket_index) do
    GenServer.cast(name, {:update_bucket, bucket_index})
  end

  def print(name) do
    GenServer.cast(name, :print)
  end

  def get(name, node_id) do
    GenServer.call(name, {:get, node_id}, @call_timeout)
  end

  def get_cache(name) do
    GenServer.call(name, :get_cache, @call_timeout)
  end

  def closest_nodes(name, target, remote_node_id) do
    GenServer.call(name, {:closest_nodes, target, remote_node_id}, @call_timeout)
  end

  def closest_nodes(name, target) do
    GenServer.call(name, {:closest_nodes, target, nil}, @call_timeout)
  end

  def del(name, node_id) do
    GenServer.call(name, {:del, node_id}, @call_timeout)
  end

  #################
  # GenServer API #
  #################

  def init(node_id: node_id, rt_name: rt_name) do
    ## Start timer for peer review
    Process.send_after(self(), :review, @review_time)

    ## Start timer for neighbourhood maintenance
    Process.send_after(self(), :neighbourhood_maintenance,
                       @neighbourhood_maintenance_time)

    ## Start timer for bucket maintenance
    Process.send_after(self(), :bucket_maintenance, @bucket_maintenance_time)

    ## Start timer for routing table dump
    Process.send_after(self(), :dump_routing_table, @dump_routing_table_time)

    ## Generate name of the ets cache table from the node_id as an atom
    ets_name = node_id |> Base.encode16() |> String.to_atom()

    {:ok, %{
        node_id:     node_id,
        node_id_enc: Base.encode16(node_id),
        rt_name:     rt_name,
        buckets:     [Bucket.new(0)],
        cache:       :ets.new(ets_name, [:set, :protected]),
     }}
  end


  @doc """
  This function gets called by an external timer. This function checks when was
  the last time a node has responded to our requests.
  """
  def handle_info(:review, state) do
    new_buckets = Enum.map(state.buckets, fn(bucket) ->
      Bucket.filter(bucket, fn(pid) ->
        time = Node.last_time_responded(pid)
        #Logger.error("time #{time/1000/60}min")
        cond do
          time < @response_time ->
            Node.send_ping(pid)

          time >= @response_time and Node.is_good?(pid) ->
            Node.goodness(pid, :questionable)
            Node.send_ping(pid)

          time >= @response_time and Node.is_questionable?(pid) ->
            #Logger.error "[#{Base.encode16 Node.id(pid)}] Deleted"
            :ets.delete(state.cache, Node.id(pid))
            Node.stop(pid)
            false
        end

      end)
    end)

    ## Restart the Timer
    Process.send_after(self(), :review, @review_time)

    {:noreply, %{state | :buckets => new_buckets}, :hibernate}
  end

  @doc """
  This functions gets called by an external timer. This function takes a random
  node from a random bucket and runs a find_node query with our own node_id as a
  target. By that way, we try to find more and more nodes that are in our
  neighbourhood.
  """
  def handle_info(:neighbourhood_maintenance, state) do
    case random_node(state.cache) do
      node_pid when is_pid(node_pid) ->
        ## Start find_node search
        target = Distance.gen_node_id(152, state[:node_id])
        node    = Node.to_tuple(node_pid)

        state.node_id_enc
        |> MlDHT.Registry.get_pid(MlDHT.Search.Supervisor)
        |> MlDHT.Search.Supervisor.start_child(:find_node, Node.socket(node_pid), state.node_id)
        |> Search.find_node(target: target, start_nodes: [node])

      nil ->
        Logger.info "Neighbourhood Maintenance: No nodes in our routing table."
    end

    ## Restart the Timer
    Process.send_after(self(), :neighbourhood_maintenance, @neighbourhood_maintenance_time)

    {:noreply, state, :hibernate}
  end

  def handle_info(:dump_routing_table, state) do
    #date = Date.utc_today() |> Date.to_string()
    #time = Time.utc_now |> Time.to_string()
    #runtime = Integer.to_string(state.run_time_clean)
    #filename = "data/dumpsnew5/#{state.node_id_enc}.txt"
    
    filename = state.node_id_enc <> ".txt"
    #filename = "data/#{date}-#{state.experiment_full_name}/#{time}/dumps/#{runtime}/#{state.node_id_enc}.txt"
    #{dir}/#{date}-#{name}/#{time}
    {:ok, file} = File.open(filename, [:write])

    state.buckets
    |> Enum.each(fn (bucket) ->
      bucket_foo = inspect(bucket)
      IO.write(file, bucket_foo)
    end)

    File.close(file)
    
    
    
    Process.send_after(self(), :dump_routing_table, @dump_routing_table_time)

    {:noreply, state, :hibernate}
  end

  @doc """
  This function gets called by an external timer. It iterates through all
  buckets and checks if a bucket has less than 6 nodes and was not updated
  during the last 15 minutes. If this is the case, then we will pick a random
  node and start a find_node query with a random_node from that bucket.

  Excerpt from BEP 0005: "Buckets that have not been changed in 15 minutes
  should be "refreshed." This is done by picking a random ID in the range of the
  bucket and performing a find_nodes search on it."
  """
  def handle_info(:bucket_maintenance, state) do
    state.buckets
    |> Stream.with_index
    |> Enum.map(fn({bucket, index}) ->
      if Bucket.age(bucket) >= @bucket_max_idle_time and Bucket.size(bucket) < 6 do
        case random_node(state.cache) do
          node_pid when is_pid(node_pid) ->
            node = Node.to_tuple(node_pid)

            ## Generate a random node_id based on the bucket
            target = Distance.gen_node_id(index, state.node_id)
            socket = Node.socket(node_pid)
            Logger.info "Staring find_node search on bucket #{index}"

            ## Start find_node search
            state.node_id_enc
            |> MlDHT.Registry.get_pid(MlDHT.Search.Supervisor)
            |> MlDHT.Search.Supervisor.start_child(:find_node, socket, state.node_id)
            |> Search.find_node(target: target, start_nodes: [node])

          nil ->
            Logger.warn "Bucket Maintenance: No nodes in our routing table."
        end

      end
    end)

    Process.send_after(self(), :bucket_maintenance, @bucket_maintenance_time)

    {:noreply, state, :hibernate}
  end

  @doc """
  This function returns the 8 closest nodes in our routing table to a specific
  target.
  """
  def handle_call({:closest_nodes, target, remote_node_id}, _from, state ) do
    list = state.cache
    |> :ets.tab2list()
    |> Enum.filter(&(elem(&1, 0) != remote_node_id))
    |> Enum.sort(fn(x, y) ->
      Distance.xor_cmp(elem(x, 0), elem(y, 0), target, &(&1 < &2))
    end)
    |> Enum.map(fn(x) -> elem(x, 1) end)
    |> Enum.slice(0..7)

    {:reply, list, state, :hibernate}
  end


  @doc """
  This functiowe will ren returns the pid for a specific node id. If the node
  does not exists, it will try to add it to our routing table. Again, if this
  was successful, this function returns the pid, otherwise nil.
  """
  def handle_call({:get, node_id}, _from, state) do
    {:reply, get_node(state.cache, node_id), state, :hibernate}
  end


  def handle_call(:get_cache, _from, state) do
    {:reply, state.cache, state, :hibernate}
  end


  @doc """
  This function returns the number of nodes in our routing table as an integer.
  """
  def handle_call(:size, _from, state) do
    size = state.buckets
    |> Enum.map(fn(b)-> Bucket.size(b) end)
    |> Enum.reduce(fn(x, acc) -> x + acc end)

    {:reply, size, state, :hibernate}
  end

  @doc """
  This function returns the number of nodes from the cache as an integer.
  """
  def handle_call(:cache_size, _from, state) do
    {:reply, :ets.tab2list(state.cache) |> Enum.count(), state, :hibernate}
  end


  @doc """
  Without parameters this function returns our own node id. If this function
  gets a string as a parameter, it will set this as our node id.
  """
  def handle_call(:node_id, _from, state) do
    {:reply, state.node_id, state, :hibernate}
  end

  def handle_call({:node_id, node_id}, _from, state) do
    ## Generate new name of the ets cache table and rename it
    ets_name  = node_id |> Base.encode16() |> String.to_atom()
    new_cache = :ets.rename(state.cache, ets_name)

    {:reply, :ok, %{state | :node_id => node_id, :cache => new_cache}, :hibernate}
  end

  @doc """
  This function deletes a node according to its node id.
  """
  def handle_call({:del, node_id}, _from, state) do
    new_bucket = del_node(state.cache, state.buckets, node_id)
    {:reply, :ok, %{state | :buckets => new_bucket}, :hibernate}
  end


  @doc """
  This function update the last_update time value in the bucket.
  """
  def handle_cast({:update_bucket, bucket_index}, state) do
    new_bucket = state.buckets
    |> Enum.at(bucket_index)
    |> Bucket.update()

    new_buckets = state.buckets
    |> List.replace_at(bucket_index, new_bucket)

    {:noreply, %{ state | :buckets => new_buckets}, :hibernate}
  end



  @doc """
  This function tries to add a new node to our routing table. If it was
  sucessful, it returns the node pid and if not it will return nil.
  """
  def handle_cast({:add, node_id, address, socket}, state) do
    #unless node_exists?(state.cache, node_id) do
    #  {:noreply, add_node(state, {node_id, address, socket}), :hibernate}
    #else
    #  {:noreply, state, :hibernate}
    #end
    
    cond do
      # This is our own node id
      node_id == state.node_id ->
        {:noreply, state, :hibernate}
      # We have this node already in our table
      node_exists?(state.cache, node_id) ->
        {:noreply, state, :hibernate}
      true ->
        {:noreply, add_node(state, {node_id, address, socket})}
    end
  end

  @doc """
  This function is for debugging purpose only. It prints out the complete
  routing table.
  """
  def handle_cast(:print, state) do
    state.buckets
    |> Enum.each(fn (bucket) ->
      Logger.debug inspect(bucket)
    end)

    {:noreply, state, :hibernate}
  end

  #####################
  # Private Functions #
  #####################

  @doc """
  This function adds a new node to our routing table.
  """
  def add_node(state, node_tuple) do
    {node_id, _ip_port, _socket} = node_tuple

    my_node_id = state.node_id
    buckets    = state.buckets
    index      = find_bucket_index(buckets, my_node_id, node_id)
    bucket     = Enum.at(buckets, index)

    cond do
      ## If the bucket has still some space left, we can just add the node to
      ## the bucket. Easy Peasy
      Bucket.has_space?(bucket) ->
        # TODO: register nodes in a registry instead of storing the pid in a bucket.
        # (the pid won't be the same after a process has been restarted by a supervisor)
        # name = MlDHT.Registry.via(..)

        node_child = {Node, own_node_id: my_node_id, node_tuple: node_tuple,
                      bucket_index: index}

        {:ok, pid} = my_node_id
        |> Base.encode16()
        |> MlDHT.Registry.get_pid(MlDHT.RoutingTable.NodeSupervisor, state.rt_name)
        |> DynamicSupervisor.start_child(node_child)

        new_bucket = Bucket.add(bucket, pid)

        :ets.insert(state.cache, {node_id, pid})
        state |> Map.put(:buckets, List.replace_at(buckets, index, new_bucket))

        ## If the bucket is full and the node would belong to a bucket that is far
        ## away from us, we will just drop that node. Go away you filthy node!
      Bucket.is_full?(bucket) and index != index_last_bucket(buckets) ->
        Logger.debug "Bucket #{index} is full -> drop #{Base.encode16(node_id)}"
        state

      ## If the bucket is full but the node is closer to us, we will reorganize
      ## the nodes in the buckets and try again to add it to our bucket list.
      true ->
          buckets = reorganize(bucket.nodes, buckets ++ [Bucket.new(index + 1)], my_node_id)
          :erlang.garbage_collect()
          add_node(%{state | :buckets => buckets}, node_tuple)
    end
  end

  @doc """
  TODO
  """
  def reorganize([], buckets, _self_node_id), do: buckets
  def reorganize([node | rest], buckets, my_node_id) do
    current_index  = length(buckets) - 2
    index          = find_bucket_index(buckets, my_node_id, Node.id(node))

    new_buckets = if (current_index != index) do
      current_bucket = Enum.at(buckets, current_index)
      new_bucket     = Enum.at(buckets, index)

      ## Remove the node from the current bucket
      filtered_bucket = Bucket.del(current_bucket, Node.id(node))

      ## Change bucket index in the Node to the new one
      Node.bucket_index(node, index)

      ## Then add it to the new_bucket
      List.replace_at(buckets, current_index, filtered_bucket)
      |> List.replace_at(index, Bucket.add(new_bucket, node))
    else
      buckets
    end

    reorganize(rest, new_buckets, my_node_id)
  end

  @doc """
  This function returns a random node pid. If the routing table is empty it
  returns nil.
  """
  def random_node(cache) do
    try do
      cache |> :ets.tab2list() |> Enum.random() |> elem(1)
    rescue
       _e in Enum.EmptyError -> nil
    end
  end


  @doc """
  Returns the index of the last bucket as integer.
  """
  def index_last_bucket(buckets) do
    Enum.count(buckets) -1
  end

  @doc """
  TODO
  """
  def find_bucket_index(buckets, self_node_id, remote_node_id) do
    unless byte_size(self_node_id) == byte_size(remote_node_id) do
      Logger.error "self_node_id: #{byte_size(self_node_id)}
      remote_node_id: #{byte_size(remote_node_id)}"

      raise ArgumentError, message: "Different length of self_node_id and remote_node_id"
    end
    bucket_index = Distance.find_bucket(self_node_id, remote_node_id)

    min(bucket_index, index_last_bucket(buckets))
  end

  @doc """
  TODO
  """
  def node_exists?(cache, node_id), do: get_node(cache, node_id)

  @doc """
  TODO
  """
  def del_node(cache, buckets, node_id) do
    {_id, node_pid} = :ets.lookup(cache, node_id) |> Enum.at(0)

    ## Delete node from the bucket list
    new_buckets = Enum.map(buckets, fn(bucket) ->
      Bucket.del(bucket, node_id)
    end)

    ## Stop the node
    Node.stop(node_pid)

    ## Delete node from the ETS cache
    :ets.delete(cache, node_id)

    new_buckets
  end

  @doc """

  """
  def get_node(cache, node_id) do
    case :ets.lookup(cache, node_id) do
      [{_node_id, pid}] -> pid
      [] -> :nil
    end
  end

end
