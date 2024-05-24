defprotocol RayTracer.Hittable do
  def hit(obj, ray, interval, rec)
end
