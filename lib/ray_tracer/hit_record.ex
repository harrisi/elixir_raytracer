defmodule RayTracer.HitRecord do
  alias RayTracer.Vec3

  defstruct [p: Vec3.new(), normal: Vec3.new(), t: 0.0, front_face: false, mat: nil]

  def new() do
    %__MODULE__{}
  end

  def set_face_normal(rec, ray, {x, y, z} = outward_normal) do
    ff = Vec3.dot(ray.direction, outward_normal) < 0
    %__MODULE__{
      rec |
      front_face: ff,
      normal: if(ff, do: Vec3.new(x, y, z), else: Vec3.new(-x, -y, -z))
    }
  end
end
