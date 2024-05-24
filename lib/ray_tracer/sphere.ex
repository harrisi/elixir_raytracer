defmodule RayTracer.Sphere do
  alias RayTracer.Vec3

  defstruct [center: Vec3.new(), radius: 0.0, mat: nil]

  def new do
    %__MODULE__{}
  end

  def new(center, radius, mat) do
    %__MODULE__{center: center, radius: max(0, radius), mat: mat}
  end
end

defimpl RayTracer.Hittable, for: RayTracer.Sphere do
  alias RayTracer.Vec3
  alias RayTracer.Ray
  alias RayTracer.HitRecord
  alias RayTracer.Interval

  def hit(%RayTracer.Sphere{} = obj, ray, %Interval{} = ray_t, rec) do
    oc = Vec3.subtract(obj.center, ray.origin)
    a = Vec3.length_squared(ray.direction)
    h = Vec3.dot(ray.direction, oc)
    c = Vec3.length_squared(oc) - obj.radius * obj.radius

    discriminant = h * h - a * c

    if discriminant < 0 do
      {false, rec}
    else
      sqrtd = :math.sqrt(discriminant)

      root = (h - sqrtd) / a
      unless Interval.surrounds(ray_t, root) do
        root = (h + sqrtd) / a
        unless Interval.surrounds(ray_t, root) do
          {false, rec}
        else
          new_p = Ray.at(ray, root)
          outward_normal = Vec3.scale(Vec3.subtract(new_p, obj.center), 1 / obj.radius)
          {true, %HitRecord{
              t: root,
              p: new_p,
              mat: obj.mat
            } |> HitRecord.set_face_normal(ray, outward_normal)
          }
        end
      else
        new_p = Ray.at(ray, root)
        outward_normal = Vec3.scale(Vec3.subtract(new_p, obj.center), 1 / obj.radius)
        {true, %HitRecord{
            t: root,
            p: new_p,
            mat: obj.mat
          } |> HitRecord.set_face_normal(ray, outward_normal)
        }
      end
    end
  end
end
