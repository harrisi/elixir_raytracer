defprotocol RayTracer.Material do
  @fallback_to_any true
  # alias RayTracer.Ray
  # alias RayTracer.HitRecord
  # alias RayTracer.Vec3

  # def scatter(%Ray{} = r_in, %HitRecord{} = rec, %Vec3{} = attenuation, %Ray{} = scattered)
  def scatter(mat, r_in, rec, attenuation, scattered)
end

defimpl RayTracer.Material, for: Any do
  alias RayTracer.Vec3
  alias RayTracer.Ray

  def scatter(_, _, _, _, _) do
    {false, Vec3.new(), Ray.new()}
  end
end
