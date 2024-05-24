defmodule RayTracer.Metal do
  alias RayTracer.Vec3

  defstruct [albedo: Vec3.new(0, 0, 0)]

  def new(albedo) do
    %__MODULE__{albedo: albedo}
  end
end

defimpl RayTracer.Material, for: RayTracer.Metal do
  alias RayTracer.Ray
  alias RayTracer.HitRecord
  alias RayTracer.Vec3

  def scatter(mat, %Ray{} = r_in, %HitRecord{} = rec, _attenuation, %Ray{} = _scattered) do
    reflected = Vec3.reflect(r_in.direction, rec.normal)
    scattered = Ray.new(rec.p, reflected)
    attenuation = mat.albedo

    {true, attenuation, scattered}
  end
end
