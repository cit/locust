defmodule Simulator do
  @moduledoc """
  Documentation for Dhtsim.
  """

  require Logger

  use Application

  alias MlDHT.Server.Utils, as: Utils

  #######################
  # Constans and Config #
  #######################

  @name __MODULE__
  
  @sec 1_000
  @min 60 * @sec
  @hour 60 * @min

  # INFO Settings
  @cfg %{
    churn_start_enabled:  true,
    churn_kill_enabled:  true,
    churn_start_malicious_enabled:  true,
    churn_kill_malicious_enabled:  true,
    dump_routing_table_node_info_enabled: true,
    dump_performance_info_enabled: true,
    dump_progress_info_enabled: true,
    churn_amount_benign: 5,
    churn_amount_malicious: 1,
    number_of_malicious_nodes: 100,
    experiment_repetitions: 1,
    number_of_benign_nodes:    [400],
    experiment_name:           "memory-footprint-v024-fixed-churn-malicious-start-offset-2h-b5-225-m1-720-final-dump",
    data_dir:                  "data",
    node_list:                 [],
    delay_measurement:         168 * @hour,
    measurement_interval:      30 * @sec,
    dump_r_table_node_info_interval:     29 * @min,
    dump_progress_info_interval: 10 * @min,
    local_ip_addr:             {127, 0, 0, 1},
    churn_kill_time:           225 * @sec,
    churn_start_time:          225 * @sec,
    churn_kill_malicious_time:           720 * @sec,
    churn_start_malicious_time:          720 * @sec,
    churn_kill_initial_delay:  60 * @sec,
    churn_start_initial_delay: 30 * @sec,
    churn_kill_malicious_initial_delay:  60 * @sec,
    churn_start_malicious_initial_delay: 30 * @sec,
    node_start_delay:          3 * @min,
    node_start_delay_malicious:          3 * @min,
    node_start_initial_delay_offset: 0,
    node_start_initial_delay_offset_malicious: 2 * @hour
  }

  ####################
  # Public Interface #
  ####################

  def start(_type, _args), do: Simulator.start_link()

  def start_link, do: GenServer.start_link(__MODULE__, [], name: @name)

  def start_simulation, do: GenServer.cast(@name, :start_simulation)

  def info, do: GenServer.cast(@name, :info)
  
  #def measure_performance, do: GenServer.cast(@name, :measure_performance)

  #####################
  # Private Interface #
  #####################

  def init([]) do
    Application.ensure_all_started(:os_mon)
    MlDHT.Registry.start()

    if @cfg.churn_kill_enabled do
      Process.send_after(self(), :churn_kill,  @cfg.churn_kill_initial_delay + @cfg.node_start_initial_delay_offset)
    end
    if @cfg.churn_start_enabled do
      Process.send_after(self(), :churn_start, @cfg.churn_start_initial_delay + @cfg.node_start_initial_delay_offset)
    end
    if @cfg.churn_kill_malicious_enabled do
      Process.send_after(self(), :churn_kill_malicious,  @cfg.churn_kill_malicious_initial_delay + @cfg.node_start_initial_delay_offset_malicious)
    end
    if @cfg.churn_start_malicious_enabled do
      Process.send_after(self(), :churn_start_malicious, @cfg.churn_start_malicious_initial_delay + @cfg.node_start_initial_delay_offset_malicious)
    end

    ## Check which remote nodes are active
    #Enum.each(@cfg.node_list, fn node -> Node.ping(node) end)

    if @cfg.dump_performance_info_enabled do
      Process.send_after(self(), :measure_performance,  @cfg.measurement_interval)
    end
    
    if @cfg.dump_routing_table_node_info_enabled do
      Process.send_after(self(), :dump_r_table_node_info,  @cfg.dump_r_table_node_info_interval)
    end
    
    if @cfg.dump_progress_info_enabled do
      Process.send_after(self(), :dump_progress_info,  @cfg.dump_progress_info_interval)
    end
    
    Process.send_after(self(), :save_memory_info,  @cfg.delay_measurement)

    {:ok, %{
        sup_pid:         nil,
        experiment_full_name: 0,
        base_dir: 0,
        filename:        0,
        filename_org:    0,
        filename_proc:    0,
        filename_pidstat:    0,
        filename_top:    0,
        filename_malicious_nodes: 0,
        filename_benign_nodes: 0,
        benign_nodes:    [],
        malicious_nodes: [],
        beam_node_list:  Node.list(),
        current_exp:     0,
        time_passed:     0,
        time_passed_clean: 0,
        time_started:    :os.system_time(:seconds),
        experiments:     get_all_experiments,
        benchmark_init:  Simulator.Benchmark.new(),
        bs_node: 0
     }}
  end

  def stop(state) do
    Logger.error "#{inspect state}"
    :ok
  end

  def handle_info(:save_memory_info, state) do
    run_time = :os.system_time(:seconds) - state.time_started
    run_time_clean = state.time_passed_clean + get_measurement_interval_seconds
    nrmal = Kernel.length(state.malicious_nodes)
    nrben = Kernel.length(state.benign_nodes)
    nrtotal = nrmal + nrben
    
    old_entry = state.benchmark_init    |> Map.from_struct()
    new_entry = Simulator.Benchmark.new |> Map.from_struct()

    entry_merge = old_entry |> Map.merge(new_entry, fn _k, v1, v2 -> v2 - v1 end)
    foo = Kernel.struct(%Simulator.Benchmark{}, entry_merge)

    state.filename
    |> Simulator.Benchmark.append_entry(%Simulator.Benchmark{foo | 
      nr_nodes: state.current_exp + @cfg.number_of_malicious_nodes,
      nr_nodes_current: nrtotal,
      nr_nodes_benign_current: nrben,
      nr_nodes_malicious_current: nrmal,
      time_passed: run_time, 
      time_passed_clean: run_time_clean}
      )
        
    state.filename_org
    |> Simulator.Benchmark.append_entry_org(%Simulator.Benchmark{foo | 
      nr_nodes: state.current_exp + @cfg.number_of_malicious_nodes,
      nr_nodes_current: nrtotal,
      nr_nodes_benign_current: nrben,
      nr_nodes_malicious_current: nrmal,
      time_passed: run_time, 
      time_passed_clean: run_time_clean}
      )
        
    # Call measurement shell script
    System.cmd("sh", ["-c", "./MeasureRAMinInterval.sh " <> get_string(state.current_exp + @cfg.number_of_malicious_nodes) <> " " <> state.experiment_full_name <> " " <> get_string(Integer.floor_div(@cfg.measurement_interval, 1_000)) <> " " <> "2" <> " " <> state.filename_proc <> " " <> state.filename_pidstat <> " " <> state.filename_top <> " " <>  get_string(run_time) <> " " <> System.pid <> " " <>  get_string(run_time_clean) <> " " <> get_string(nrtotal) <> " " <> get_string(nrben) <> " " <> get_string(nrmal)])
    
    
    Process.send_after(self(), :save_memory_info,  @cfg.delay_measurement)
    DynamicSupervisor.stop(state.sup_pid)

    #Logger.error "Foo: #{inspect state.experiments}"

    if state.experiments == [] do
      cfg_str = :erlang.term_to_binary(@cfg)
      cfg_str = inspect(@cfg)

      {:ok, file} = state.filename
      |> String.replace_trailing(".csv", "-config.txt")
      |> File.open([:write])

      IO.write(file, cfg_str)
      File.close(file)
      
      System.cmd("sh", ["-c", "./MeasureRAMinInterval.sh " <> "1000" <> " " <> state.experiment_full_name <> " " <> get_string(Integer.floor_div(@cfg.measurement_interval, 1_000)) <> " " <> "3" <> " " <> state.filename_proc <> " " <> state.filename_pidstat <> " " <> state.filename_top <> " " <> "0" <> " " <> System.pid <> " " <>  get_string(run_time_clean) <> " " <> get_string(nrtotal) <> " " <> get_string(nrben) <> " " <> get_string(nrmal)])

      System.halt(0)
    else
      Simulator.start_simulation()
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _, _}, state) do
    Logger.error("Node DOWN")
    {:noreply, state}
  end

  def handle_info(:churn_kill, state) do
    if Kernel.length(state.benign_nodes) > 0 do
    
    :random.seed(:erlang.now)
    list_kill_nodes = state.benign_nodes |> Enum.take_random(@cfg.churn_amount_benign)
    list_kill_nodes |> Enum.each(fn (kill_node) ->
      {pid, _node_id} = kill_node
      Process.exit(pid, :kill)
    end) 
 
    Process.send_after(self(), :churn_kill, @cfg.churn_kill_time)
    {:noreply, %{state | :benign_nodes => state.benign_nodes -- list_kill_nodes }}
    else
    Process.send_after(self(), :churn_kill, @cfg.churn_kill_time)
    {:noreply, state}
    end
  end
  
  def handle_info(:churn_kill_malicious, state) do
    if Kernel.length(state.malicious_nodes) > 0 do
    
    :random.seed(:erlang.now)
    list_kill_nodes = state.malicious_nodes |> Enum.take_random(@cfg.churn_amount_malicious)
    list_kill_nodes |> Enum.each(fn (kill_node) ->
      {pid, _node_id} = kill_node
      Process.exit(pid, :kill)
    end) 
    
    Process.send_after(self(), :churn_kill_malicious, @cfg.churn_kill_malicious_time)
    {:noreply, %{state | :malicious_nodes => state.malicious_nodes -- list_kill_nodes }}
    else
    Process.send_after(self(), :churn_kill_malicious, @cfg.churn_kill_malicious_time)
    {:noreply, state}
    end
  end

  def handle_info(:churn_start, state) do
    new_benign_nodes = spawn_nodes(@cfg.churn_amount_benign, :benign, state.beam_node_list)
    Process.send_after(self(), :churn_start, @cfg.churn_start_time)
   {:noreply, %{ state | :benign_nodes => state.benign_nodes ++ new_benign_nodes }}
  end
  
  def handle_info(:churn_start_malicious, state) do
    new_malicious_nodes = spawn_nodes(@cfg.churn_amount_malicious, :malicious, state.beam_node_list)
    Process.send_after(self(), :churn_start_malicious, @cfg.churn_start_malicious_time)
    {:noreply, %{ state | :malicious_nodes => state.malicious_nodes ++ new_malicious_nodes }}
  end

  def handle_cast(:start_simulation, state) do
    ## Check which remote nodes are active
    Enum.each(@cfg.node_list, fn node -> Node.ping(node) end)
    {:ok, sup_pid} = Simulator.Supervisor.start_link([])

    bs_node_id     = Utils.gen_node_id()
    bs_node_id_enc = bs_node_id |> Base.encode16()
    Logger.error "Bootstraping Server: #{inspect bs_node_id_enc}"

    Application.put_env(:mldht, :port, 1111)

    {:ok, _bs_pid} = DynamicSupervisor.start_child(sup_pid,
      {MlDHT.Supervisor,
       node_id: bs_node_id,
       delay:   0,
       name:    MlDHT.Registry.via(bs_node_id_enc, MlDHT.Supervisor)
    })

    bs_node = [{bs_node_id_enc, @cfg.local_ip_addr, 1111}]
    Application.put_env(:mldht, :port, 0)
    Application.put_env(:mldht, :bootstrap_nodes, bs_node)

    [current | rest] = state.experiments
    
    experiment_full_name = get_experiment_full_name
    base_dir = get_experiment_base_path(current)
    File.mkdir_p(base_dir)
    
    if @cfg.dump_routing_table_node_info_enabled do
      create_visualization_run_script("#{base_dir}/dumps/")
    end

    filename = generate_filename(base_dir)
    filename_org = generate_filename_org(base_dir)
    filename_proc = generate_filename_proc(base_dir)
    filename_pidstat = generate_filename_pidstat(base_dir)
    filename_top = generate_filename_top(base_dir)
    filename_malicious_nodes = generate_filename_malicious_nodes(base_dir)
    filename_benign_nodes = generate_filename_benign_nodes(base_dir)
    
    Simulator.Benchmark.create_file(filename)
    Simulator.Benchmark.create_file_org(filename_org)
    
    # Create initial performance measurement
    System.cmd("sh", ["-c", "./MeasureRAMinInterval.sh " <> "1000" <> " " <> experiment_full_name <> " " <> get_string(Integer.floor_div(@cfg.measurement_interval, 1_000)) <> " " <> "1" <> " " <> filename_proc <> " " <> filename_pidstat <> " " <> filename_top <> " " <> "0" <> " " <> System.pid <> " 1000 1000 1000 1000"])

    Logger.error "Start with #{current} nodes"

    {:noreply, %{state |
        :sup_pid         => sup_pid,
        :current_exp     => current,
        :experiments     => rest,
        :experiment_full_name => experiment_full_name,
        :base_dir => base_dir,
        :filename =>        filename,
        :filename_org =>    filename_org,
        :filename_proc =>    filename_proc,
        :filename_pidstat =>    filename_pidstat,
        :filename_top =>    filename_top,
        :filename_malicious_nodes => filename_malicious_nodes,
        :filename_benign_nodes => filename_benign_nodes,
        :time_passed     => 0,
        :time_passed_clean => 0,
        :time_started    => :os.system_time(:seconds),
        :benign_nodes    => spawn_nodes_initial_offset(current, :benign, state.beam_node_list),
        :malicious_nodes => spawn_nodes_initial_offset(@cfg.number_of_malicious_nodes, :malicious, state.beam_node_list),
        :bs_node => bs_node_id_enc
    }}
  end

  def handle_cast(:info, state) do
    IO.puts "Process running: #{Process.list |> Enum.count}"
    foo = state.sup_pid
    |> DynamicSupervisor.which_children()
    |> Enum.count

    IO.puts "info #{inspect foo}"
    mem_usage_wo = 17992568

    mem_diff = :erlang.memory(:total) - mem_usage_wo
    mem_diff_hr = div(mem_diff, 1024*1024)
    IO.puts "mem: #{inspect mem_diff} (#{inspect mem_diff_hr})"
    
    {:noreply, state}
  end

  def spawn_nodes(n, type, beam_node_list), do: spawn_nodes(n, type, [], beam_node_list)
  def spawn_nodes(0, _type, node_list, _beam_node_list), do: node_list
  def spawn_nodes(n, type, node_list, []) do
    ## Generate a new node ID
    node_id     = Utils.gen_node_id()
    node_id_enc = node_id |> Base.encode16()
    delay = cond do
      type == :benign ->
        :rand.uniform(@cfg.node_start_delay)
      type == :malicious ->
        :rand.uniform(@cfg.node_start_delay_malicious)
    end

    # Start the main supervisor for the dht node
    {:ok, pid} = DynamicSupervisor.start_child(Simulator.Supervisor,
      {MlDHT.Supervisor,
       node_id: node_id,
       delay:   delay,
       name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
      })

    spawn_nodes(n-1, type, node_list ++ [{pid, node_id}], [])
  end
  def spawn_nodes(n, type, node_list, [remote_node | beam_node_list]) do
    ## Generate a new node ID
    node_id     = Utils.gen_node_id()
    node_id_enc = node_id |> Base.encode16()
    delay = cond do
      type == :benign ->
        :rand.uniform(@cfg.node_start_delay)
      type == :malicious ->
        :rand.uniform(@cfg.node_start_delay_malicious)
    end

    Logger.error "REMOTE NODE #{inspect remote_node}"
    Logger.error "Node-ID: #{node_id_enc}"
    Logger.error "Delay:   #{delay}"

    args = [
      node_id: node_id,
      delay:   delay,
      name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
    ]

    bs_node = Application.get_env(:mldht, :bootstrap_nodes)

    # Start the main supervisor for the dht node
    {:ok, pid} = DynamicSupervisor.start_child(Simulator.Supervisor,
      {MlDHT.Supervisor,
       node_id: node_id,
       delay:   delay,
       name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
      })
    spawn_nodes(n-1, type, node_list ++ [{pid, node_id}], beam_node_list)
  end
  
  def spawn_nodes_initial_offset(n, type, beam_node_list), do: spawn_nodes_initial_offset(n, type, [], beam_node_list)
  def spawn_nodes_initial_offset(0, _type, node_list, _beam_node_list), do: node_list
  def spawn_nodes_initial_offset(n, type, node_list, []) do
    ## Generate a new node ID
    node_id     = Utils.gen_node_id()
    node_id_enc = node_id |> Base.encode16()
    delay = cond do
      type == :benign ->
        @cfg.node_start_initial_delay_offset + :rand.uniform(@cfg.node_start_delay)
      type == :malicious ->
        @cfg.node_start_initial_delay_offset_malicious + :rand.uniform(@cfg.node_start_delay_malicious)
    end

    # Start the main supervisor for the dht node
    {:ok, pid} = DynamicSupervisor.start_child(Simulator.Supervisor,
      {MlDHT.Supervisor,
       node_id: node_id,
       delay:   delay,
       name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
      })

    spawn_nodes_initial_offset(n-1, type, node_list ++ [{pid, node_id}], [])
  end
  def spawn_nodes_initial_offset(n, type, node_list, [remote_node | beam_node_list]) do
    ## Generate a new node ID
    node_id     = Utils.gen_node_id()
    node_id_enc = node_id |> Base.encode16()
    delay = cond do
      type == :benign ->
        @cfg.node_start_initial_delay_offset + :rand.uniform(@cfg.node_start_delay)
      type == :malicious ->
        @cfg.node_start_initial_delay_offset_malicious + :rand.uniform(@cfg.node_start_delay_malicious)
    end

    Logger.error "REMOTE NODE #{inspect remote_node}"
    Logger.error "Node-ID: #{node_id_enc}"
    Logger.error "Delay:   #{delay}"

    args = [
      node_id: node_id,
      delay:   delay,
      name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
    ]

    bs_node = Application.get_env(:mldht, :bootstrap_nodes)

    # Start the main supervisor for the dht node
    {:ok, pid} = DynamicSupervisor.start_child(Simulator.Supervisor,
      {MlDHT.Supervisor,
       node_id: node_id,
       delay:   delay,
       name:    MlDHT.Registry.via(node_id_enc, MlDHT.Supervisor)
      })

    spawn_nodes_initial_offset(n-1, type, node_list ++ [{pid, node_id}], beam_node_list)
  end
      
  def get_experiment_base_path(current_exp) do
    date = Date.utc_today() |> Date.to_string()
    time = Time.utc_now |> Time.to_string()
    "#{@cfg.data_dir}/#{date}-#{get_experiment_full_name}/#{current_exp}-#{time}"
  end

  def generate_filename(base_dir) do
    "#{base_dir}/results.csv"
  end
  
  def generate_filename_org(base_dir) do
    "#{base_dir}/results-org.csv"
  end
  
  def generate_filename_proc(base_dir) do
    "#{base_dir}/results-proc.csv"
  end
  
  def generate_filename_pidstat(base_dir) do
    "#{base_dir}/results-pidstat.csv"
  end
  
  def generate_filename_top(base_dir) do
    "#{base_dir}/results-top.csv"
  end
  
  def generate_filename_malicious_nodes(base_dir) do
    "#{base_dir}/MaliciousNodes"
  end
  
  def generate_filename_benign_nodes(base_dir) do
    "#{base_dir}/BenignNodes"
  end
  
  def generate_filename_dumps_base(base_dir, time_passed) do
    "#{base_dir}/dumps/#{time_passed}/"
  end
  
  def handle_info(:measure_performance, state) do
    run_time = :os.system_time(:seconds) - state.time_started
    run_time_clean = state.time_passed_clean + get_measurement_interval_seconds
    nrmal = Kernel.length(state.malicious_nodes)
    nrben = Kernel.length(state.benign_nodes)
    nrtotal = nrmal + nrben
  
    old_entry = state.benchmark_init    |> Map.from_struct()
    new_entry = Simulator.Benchmark.new |> Map.from_struct()

    entry_merge = old_entry |> Map.merge(new_entry, fn _k, v1, v2 -> v2 - v1 end)
    foo = Kernel.struct(%Simulator.Benchmark{}, entry_merge)

    state.filename
    |> Simulator.Benchmark.append_entry(%Simulator.Benchmark{foo | 
      nr_nodes: state.current_exp + @cfg.number_of_malicious_nodes,
      nr_nodes_current: nrtotal,
      nr_nodes_benign_current: nrben,
      nr_nodes_malicious_current: nrmal,
      time_passed: run_time, 
      time_passed_clean: run_time_clean}
      )
        
    state.filename_org
    |> Simulator.Benchmark.append_entry_org(%Simulator.Benchmark{foo | 
      nr_nodes: state.current_exp + @cfg.number_of_malicious_nodes,
      nr_nodes_current: nrtotal,
      nr_nodes_benign_current: nrben,
      nr_nodes_malicious_current: nrmal,
      time_passed: run_time, 
      time_passed_clean: run_time_clean}
      )

      # Run performance measurement script
      System.cmd("sh", ["-c", "./MeasureRAMinInterval.sh " <> get_string(state.current_exp + @cfg.number_of_malicious_nodes) <> " " <> state.experiment_full_name <> " " <> get_string(Integer.floor_div(@cfg.measurement_interval, 1_000)) <> " " <> "2" <> " " <> state.filename_proc <> " " <> state.filename_pidstat <> " " <> state.filename_top <> " " <>  get_string(run_time) <> " " <> System.pid <> " " <>  get_string(run_time_clean) <> " " <> get_string(nrtotal) <> " " <> get_string(nrben) <> " " <> get_string(nrmal)])

    Process.send_after(self(), :measure_performance,  @cfg.measurement_interval)

    {:noreply, %{state |
                 :time_passed => run_time,
                 :time_passed_clean => run_time_clean
                }}
  end
  
  def handle_info(:dump_progress_info, state) do
    time_remaining = Integer.floor_div(@cfg.delay_measurement,1000) - state.time_passed_clean
    hours = Integer.floor_div(time_remaining,60*60)
    minutes = Integer.floor_div((time_remaining - hours*60*60), 60)
    seconds = time_remaining - hours*60*60 - minutes*60
    # Print remaining experiment run time
    Logger.error("#{hours}h #{minutes}m #{seconds}s remaining")
    Process.send_after(self(), :dump_progress_info,  @cfg.dump_progress_info_interval)
    {:noreply, state}
  end
  
  def handle_info(:dump_r_table_node_info, state) do
    malnodes = Enum.map(state.malicious_nodes, fn ({x, y}) -> {x, Base.encode16(y)} end)
    goodnodes = Enum.map(state.benign_nodes, fn ({x, y}) -> {x, Base.encode16(y)} end)
    malnodesFormatted = Enum.map(malnodes, fn({x,y}) ->
          "#{inspect y}\n"
        end)

    malnodesFormattedOutput = """
    #{malnodesFormatted}
    """
    
    goodnodesFormatted = Enum.map(goodnodes, fn({x,y}) ->
          "#{inspect y}\n"
        end)
    
    goodnodesFormattedOutput = """
    #{goodnodesFormatted}
    """
    
    filenamemalicious = "#{state.filename_malicious_nodes}-T#{state.time_passed_clean}.txt"
    {:ok, file2} = File.open(filenamemalicious, [:write])
    IO.write(file2, "#{malnodesFormattedOutput}")
    File.close(file2)
    
    filenamegood = "#{state.filename_benign_nodes}-T#{state.time_passed_clean}.txt"
    {:ok, file3} = File.open(filenamegood, [:write])
    IO.write(file3, "Bootstrap node: #{inspect state.bs_node}\n")
    IO.write(file3, "#{goodnodesFormattedOutput}")
    File.close(file3)
    
    time_p = state.time_passed_clean
    
    dump_analysis_script(goodnodes, malnodes, state.bs_node, state.base_dir, time_p)
    
    Process.send_after(self(), :dump_r_table_node_info,  @cfg.dump_r_table_node_info_interval)

    {:noreply, state}
  end
  
  defp get_experiment_max_nodes do
    Enum.max(@cfg.number_of_benign_nodes)
  end
  
  defp get_experiment_min_nodes do
    Enum.min(@cfg.number_of_benign_nodes)
  end
  
  defp get_experiment_run_time do
    Integer.floor_div(@cfg.delay_measurement,(60*1000))
  end
  
  defp get_measurement_interval_seconds do
    Integer.floor_div(@cfg.measurement_interval,1000)
  end
  
  defp get_string(int) do
    Integer.to_string(int)
  end
  
  defp get_all_experiments do
    @cfg.number_of_benign_nodes |> List.duplicate(@cfg.experiment_repetitions) |> List.flatten
  end
  
  defp get_experiment_full_name do
    @cfg.experiment_name <> "-" <> get_string(get_experiment_max_nodes()) <> "-" <>  get_string(get_experiment_min_nodes()) <> "-" <> get_string(get_experiment_run_time()) <> "min-" <> get_string(@cfg.experiment_repetitions) <> "reps"
  end
  
  # Create analysis shell scripts for use in automatic analysis and visualization
  defp dump_analysis_script(goodnodes, malnodes, bs_node, base_dir, time_p) do
    nrgoodnodes = Kernel.length(goodnodes)
    nrbadnodes = Kernel.length(malnodes)
    
    malnodesFormatted = Enum.map(malnodes, fn({x,y}) ->
          "#{inspect y} "
        end)
    
    malnodesFormattedOutput = """
    Malnodes=(#{malnodesFormatted})
    """
  
    name_base = generate_filename_dumps_base(base_dir, time_p)
    File.mkdir_p(name_base)
    filenameanalysis = "#{name_base}AnalysisScript-T#{time_p}.sh"
    
    {:ok, file} = File.open(filenameanalysis, [:write])
    
    IO.write(file, """
#! /bin/bash
BadNodes=#{nrbadnodes}
GoodNodes=#{nrgoodnodes}
#{malnodesFormattedOutput}
Centernode=#{bs_node}
for f in *.txt ; do 
awk -i inplace '!seen[$0]++' $f
sed -i -e 's/ -- /\\"'$(basename "$f" .txt)'\\" -- /g' $f 
#sed -i -e 's/,|.*/\\"'$(basename "$f" .txt)'\\"/g' $f 
sed -i -e 's/,|/\\"'$(basename "$f" .txt)'\\"/g' $f 
sed -i -e 's/]/];/g' $f 
done
cat *.txt > fulldump.dot
sed -i -E '/^$/d' fulldump.dot
sed -i '1 i\\graph{' fulldump.dot
sed -i '1 a\\node [shape=circle color=black width=3 style=filled fixedsize=true fontsize=12 fontcolor=black];' fulldump.dot
sed -i '2 a\\edge [style=invis];' fulldump.dot

for j in ${Malnodes[@]}; do
sed -i '3 a\\"'${j}'"[width=5];' fulldump.dot
done

cp fulldump.dot fulldumpWithCenterNode.dot
sed -i '/'${Centernode}'/d' fulldump.dot

for k in ${Malnodes[@]}; do
sed -i -E 's/("('${k}').*\\[)/\\1style=\\"\\", color=red, /g' fulldump.dot
sed -i -E 's/("('${k}').*\\[)/\\1style=\\"\\", color=red, /g' fulldumpWithCenterNode.dot
done

sed -i '$ a\\}' fulldump.dot
sed -i '$ a\\}' fulldumpWithCenterNode.dot

sed -i '/^$/d' fulldump.dot
sed -i '/^$/d' fulldumpWithCenterNode.dot

cp fulldump.dot fulldumpAllEdges.dot
cp fulldumpWithCenterNode.dot fulldumpAllEdgesWithCenterNode.dot

sfdp -x -Goverlap=scale fulldump.dot | gvmap -e | neato -n2 -Tpdf > graphT#{time_p}.pdf
sfdp -x -Goverlap=scale fulldumpWithCenterNode.dot | gvmap -e | neato -n2 -Tpdf > graphWithCenterNodeT#{time_p}.pdf
#sfdp -x -Goverlap=scale fulldump.dot | gvmap -e | neato -n2 -Tpng > graphT#{time_p}.png

sed -i -E 's/edge \\[style=invis];/edge \\[style=\\"\\"\\];/' fulldumpAllEdges.dot
sed -i -E 's/edge \\[style=invis];/edge \\[style=\\"\\"\\];/' fulldumpAllEdgesWithCenterNode.dot

sfdp -x -Goverlap=scale fulldumpAllEdges.dot | gvmap -e | neato -n2 -Tpdf > graphEdgesT#{time_p}.pdf
sfdp -x -Goverlap=scale fulldumpAllEdgesWithCenterNode.dot | gvmap -e | neato -n2 -Tpdf > graphEdgesWithCenterNodeT#{time_p}.pdf
#sfdp -x -Goverlap=scale fulldump.dot | gvmap -e | neato -n2 -Tpng > graphEdgesT#{time_p}.png



Lines=0
TotalLines=0
MaliciousWeights=0
TotalWeights=0

LinesWithCenterNode=0
TotalLinesWithCenterNode=0
MaliciousWeightsWithCenterNode=0
TotalWeightsWithCenterNode=0

#sed -i -E '/^$/d' fulldump.dot

for j in ${Malnodes[@]}; do
Lines=$(($Lines+$(grep ${j} fulldump.dot | wc -l)))
grep -E ${j}.*weight=[0-9]+ fulldump.dot >> testfile.txt

LinesWithCenterNode=$(($LinesWithCenterNode+$(grep ${j} fulldumpWithCenterNode.dot | wc -l)))
grep -E ${j}.*weight=[0-9]+ fulldumpWithCenterNode.dot >> testfileWithCenterNode.txt
done

grep -E .*weight=[0-9]+ fulldump.dot >> testfile2.txt
grep -E .*weight=[0-9]+ fulldumpWithCenterNode.dot >> testfile2WithCenterNode.txt

sed -i -E 's/.*weight=//g' testfile.txt
sed -i -E 's/\\];//g' testfile.txt

sed -i -E 's/.*weight=//g' testfile2.txt
sed -i -E 's/\\];//g' testfile2.txt

sed -i -E 's/.*weight=//g' testfileWithCenterNode.txt
sed -i -E 's/\\];//g' testfileWithCenterNode.txt

sed -i -E 's/.*weight=//g' testfile2WithCenterNode.txt
sed -i -E 's/\\];//g' testfile2WithCenterNode.txt

TotalLines=$(($TotalLines + $(grep "\\n" fulldump.dot | wc -l)))
TotalLines=$(($TotalLines - $BadNodes - 4))
echo Good Nodes: ${GoodNodes} >> AnalysisResults.txt
echo Bad Nodes: ${BadNodes} >> AnalysisResults.txt
echo Malicious Edges: ${Lines} >> AnalysisResults.txt
echo Total Lines: ${TotalLines} >> AnalysisResults.txt
MaliciousWeights=$((${MaliciousWeights} + $(( echo 0 ; sed "s/$/ +/" testfile.txt ; echo p ) | dc)))
echo Malicious Weights: ${MaliciousWeights} >> AnalysisResults.txt
TotalWeights=$((${TotalWeights} + $(( echo 0 ; sed "s/$/ +/" testfile2.txt ; echo p ) | dc)))
echo Total Weights: ${TotalWeights} >> AnalysisResults.txt
echo Malicious Edge Percentage: $((${Lines}*100 / ${TotalLines})) % >> AnalysisResults.txt
echo MaliciousWeightPercentage: $((${MaliciousWeights}*100 / ${TotalWeights})) % >> AnalysisResults.txt
echo GoodBad Node Percentage: $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) % >> AnalysisResults.txt

TotalLinesWithCenterNode=$((TotalLinesWithCenterNode + $(grep "\\n" fulldumpWithCenterNode.dot | wc -l)))
TotalLinesWithCenterNode=$((TotalLinesWithCenterNode - $BadNodes - 4))
echo Good Nodes With Center Node: ${GoodNodes} >> AnalysisResults.txt
echo Bad Nodes With Center Node: ${BadNodes} >> AnalysisResults.txt
echo Malicious Edges With Center Node: ${LinesWithCenterNode} >> AnalysisResults.txt
echo Total Lines With Center Node: ${TotalLinesWithCenterNode} >> AnalysisResults.txt
MaliciousWeightsWithCenterNode=$((${MaliciousWeightsWithCenterNode} + $(( echo 0 ; sed "s/$/ +/" testfileWithCenterNode.txt ; echo p ) | dc)))
echo Malicious Weights With Center Node: ${MaliciousWeightsWithCenterNode} >> AnalysisResults.txt
TotalWeightsWithCenterNode=$((${TotalWeightsWithCenterNode} + $(( echo 0 ; sed "s/$/ +/" testfile2WithCenterNode.txt ; echo p ) | dc)))
echo Total Weights With Center Node: ${TotalWeightsWithCenterNode} >> AnalysisResults.txt
echo Malicious Edge Percentage With Center Node: $((${LinesWithCenterNode}*100 / ${TotalLinesWithCenterNode})) % >> AnalysisResults.txt
echo MaliciousWeightPercentage With Center Node: $((${MaliciousWeightsWithCenterNode}*100 / ${TotalWeightsWithCenterNode})) % >> AnalysisResults.txt

echo \\| Nodes \\| Type    \\| Value \\| GoodNodes \\| BadNodes \\| MaliciousEdges \\| TotalEdges \\| MaliciouslWeights \\| TotalWeights \\| Timestamp \\|>> OrgModeExport.txt
echo \\|-------+---------+-------+-----------+----------+----------------+------------+-------------------+--------------+-\\| >> OrgModeExport.txt
echo \\| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \\| Edges \\| $((${Lines}*100 / ${TotalLines})) \\| ${GoodNodes} \\|  ${BadNodes} \\| ${Lines} \\| ${TotalLines} \\| ${MaliciousWeights} \\| ${TotalWeights} \\| #{inspect time_p} \\| >> OrgModeExport.txt
echo \\| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \\| Weights \\| $((${MaliciousWeights}*100 / ${TotalWeights})) \\| ${GoodNodes} \\|  ${BadNodes} \\| ${Lines} \\| ${TotalLines} \\| ${MaliciousWeights} \\| ${TotalWeights} \\| #{inspect time_p} \\| >> OrgModeExport.txt
echo \\| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \\| EdgesWithCenterNode \\| $((${LinesWithCenterNode}*100 / ${TotalLinesWithCenterNode})) \\| ${GoodNodes} \\|  ${BadNodes} \\| ${LinesWithCenterNode} \\| ${TotalLinesWithCenterNode} \\| ${MaliciousWeightsWithCenterNode} \\| ${TotalWeightsWithCenterNode} \\| #{inspect time_p} \\| >> OrgModeExport.txt
echo \\| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \\| WeightsWithCenterNode \\| $((${MaliciousWeightsWithCenterNode}*100 / ${TotalWeightsWithCenterNode})) \\| ${GoodNodes} \\|  ${BadNodes} \\| ${LinesWithCenterNode} \\| ${TotalLinesWithCenterNode} \\| ${MaliciousWeightsWithCenterNode} \\| ${TotalWeightsWithCenterNode} \\| #{inspect time_p} \\| >> OrgModeExport.txt

rm testfile.txt
rm testfile2.txt
rm testfileWithCenterNode.txt
rm testfile2WithCenterNode.txt


exit
    """)
    
    File.close(file)
    
    Enum.each(malnodes, fn ({x, y}) -> File.cp("#{y}.txt", "#{name_base}#{y}.txt") end)
    Enum.each(goodnodes, fn ({x, y}) -> File.cp("#{y}.txt", "#{name_base}#{y}.txt") end)
  end
  
  # Create automatic network graph visualization shell scripts
  defp create_visualization_run_script(name_base) do
    File.mkdir_p(name_base)
    
    filename = "#{name_base}CreateVisualizations.sh"
    
    {:ok, file} = File.open(filename, [:write])
    
    IO.write(file, """
    #! /bin/bash
    for d in *; do
      ( cd "$d" && sh "./AnalysisScript-T$d.sh" && echo "$d done" )
    done
    sh ./ConcatenateAnalysisResults.sh
    sh ./CopyResultData.sh
    """)
    
    File.close(file)

    filename2 = "#{name_base}ConcatenateAnalysisResults.sh"
    {:ok, file2} = File.open(filename2, [:write])
    IO.write(file2, """
    #! /bin/bash
    for d in *; do
      ( cd "$d" && cat OrgModeExport.txt >> ../OrgModeExportFull.csv )
    done
    awk -i inplace '!seen[$0]++' OrgModeExportFull.csv
    sed -E 's/\\|/,/g' OrgModeExportFull.csv > OrgModeExportFullComma.csv
    sed -i -E '/^,-+/d' OrgModeExportFullComma.csv
    
    sed -E 's/,/\\./g' ../results-proc.csv > ../results-proc-comma.csv
    sed -i -E 's/\\|/,/g' ../results-proc-comma.csv
    sed -i -E '/^,-+/d' ../results-proc-comma.csv
    
    sed -E 's/,/\\./g' ../results-top.csv > ../results-top-comma.csv
    sed -i -E 's/\\|/,/g' ../results-top-comma.csv
    sed -i -E '/^,-+/d' ../results-top-comma.csv
    """)
    File.close(file2)
    
    filename3 = "#{name_base}CopyResultData.sh"
    {:ok, file3} = File.open(filename3, [:write])
    IO.write(file3, """
    #! /bin/bash
    rm -r ../../../PaperExperimentsFinal/NewData
    
    mkdir ../../../PaperExperimentsFinal/NewData
    mkdir ../../../PaperExperimentsFinal/NewData/data
    mkdir ../../../PaperExperimentsFinal/NewData/plots
    mkdir ../../../PaperExperimentsFinal/NewData/visualizations
    
    for d in *; do
      ( cd "$d" && cp graph*.pdf ../../../../PaperExperimentsFinal/NewData/visualizations/ )
    done
    
    cp OrgModeExportFull* ../../../PaperExperimentsFinal/NewData/data/
    cp ../results* ../../../PaperExperimentsFinal/NewData/data/
    """)
    File.close(file3)
  end
end
