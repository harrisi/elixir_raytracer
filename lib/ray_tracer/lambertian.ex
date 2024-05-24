defmodule RayTracer.Lambertian do
  alias RayTracer.Vec3

  defstruct [albedo: Vec3.new(0, 0, 0)]

  def new(albedo) do
    %__MODULE__{albedo: albedo}
  end
end

defimpl RayTracer.Material, for: RayTracer.Lambertian do
  alias RayTracer.Ray
  alias RayTracer.HitRecord
  alias RayTracer.Vec3
  alias RayTracer.Ray

  def scatter(mat, %Ray{} = _r_in, %HitRecord{} = rec, _attenuation, %Ray{} = _scattered) do
    scatter_direction = Vec3.add(rec.normal, Vec3.random_unit_vector())

    scatter_direction = if Vec3.near_zero(scatter_direction) do
      rec.normal
    else
      scatter_direction
    end

    scattered = Ray.new(rec.p, scatter_direction)
    attenuation = mat.albedo

    {true, attenuation, scattered}
  end
end
