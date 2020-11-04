defmodule Memory do

  def memory_hungriest_pids(n) do
    Process.list()
    |> Stream.map(&( {&1, elem(Process.info(&1, :heap_size),1) }))
    |> Enum.sort(fn(x, y) -> elem(x, 1) > elem(y, 1) end)
    |> Enum.take(n)
  end


end
