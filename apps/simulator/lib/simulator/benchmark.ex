defmodule Simulator.Benchmark do

  require Logger

  alias __MODULE__

  defstruct nr_nodes: 0,
    nr_nodes_current: 0,
    nr_nodes_benign_current: 0,
    nr_nodes_malicious_current: 0,
    nr_processes: 0,
    total: 0,
    processes: 0,
    processes_used: 0,
    system: 0,
    atom: 0,
    atom_used: 0,
    binary: 0,
    code: 0,
    ets: 0,
    time_passed: 0,
    time_passed_clean: 0,
    cpu_util: 0,
    cpu_avg1: 0,
    cpu_avg5: 0

  def new() do
    %Benchmark{
      total:          :erlang.memory(:total),
      processes:      :erlang.memory(:processes),
      processes_used: :erlang.memory(:processes_used),
      system:         :erlang.memory(:system),
      atom:           :erlang.memory(:atom),
      atom_used:      :erlang.memory(:atom_used),
      binary:         :erlang.memory(:binary),
      code:           :erlang.memory(:code),
      ets:            :erlang.memory(:ets),
      nr_processes:   Process.list |> Enum.count(),
      cpu_util:       :cpu_sup.util(),
      cpu_avg1:       :cpu_sup.avg1(),
      cpu_avg5:       :cpu_sup.avg5()
    }
  end

  def create_file(filename) do
    File.mkdir_p!(Path.dirname(filename))
    {:ok, file} = File.open(filename, [:write])
    IO.write(file, headers_str())
    File.close(file)
  end

  def append_entry(filename, %Benchmark{} = entry) do
    {:ok, file} = File.open(filename, [:append])

    entry_str = entry
    |> Map.from_struct()
    |> Map.values()
    |> inspect
    |> String.slice(1..-2)
    |> Kernel.<>("\n")

    IO.write(file, entry_str)
    File.close(file)
  end

  def headers_str do
    %Benchmark{}
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.map(&( Atom.to_string(&1) ))
    |> inspect
    |> String.slice(1..-2)
    |> Kernel.<>("\n")
  end
  
  def create_file_org(filename_org) do
    File.mkdir_p!(Path.dirname(filename_org))
    {:ok, file_org} = File.open(filename_org, [:write])
    IO.write(file_org, headers_str_org())
    File.close(file_org)
  end
  
  # Emacs org-mode table export
  def headers_str_org do
    %Benchmark{}
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.map(&( Atom.to_string(&1) ))
    |> inspect
    |> String.slice(1..-2)
    |> String.replace(",","|")
    |> String.replace("", "|", global: false)
    |> Kernel.<>("|\n")
  end
  
  # Emacs org-mode table export
  def append_entry_org(filename_org, %Benchmark{} = entry) do
    {:ok, file_org} = File.open(filename_org, [:append])

    entry_str_org = entry
    |> Map.from_struct()
    |> Map.values()
    |> inspect
    |> String.slice(1..-2)
    |> String.replace(",","|")
    |> String.replace("", "|", global: false)
    |> Kernel.<>("|\n")

    IO.write(file_org, entry_str_org)
    File.close(file_org)
  end

end
