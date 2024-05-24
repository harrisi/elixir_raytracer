defmodule RayTracer.Ray do
  defstruct [:origin, :direction]

  alias RayTracer.Vec3

  def new() do
    %__MODULE__{}
  end

  def new(origin, direction) do
    %__MODULE__{origin: origin, direction: direction}
  end
  
  def at(%__MODULE__{origin: origin, direction: direction}, t) when is_number(t) do
    scaled = Vec3.scale(direction, t)
    origin |> Vec3.add(scaled)
  end
end
