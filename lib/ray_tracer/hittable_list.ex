defmodule RayTracer.HittableList do
  defstruct [objects: []]

  def new do
    %__MODULE__{}
  end
end

defimpl RayTracer.Hittable, for: RayTracer.HittableList do
  alias RayTracer.HitRecord
  alias RayTracer.Hittable
  alias RayTracer.Interval

  def hit(obj, ray, %Interval{} = ray_t, rec) do
    temp_rec = HitRecord.new()
    closest_so_far = ray_t.max

    Enum.reduce(obj.objects, {false, rec}, fn o, {hit_anything_acc, rec_acc} ->
      case Hittable.hit(o, ray, Interval.new(ray_t.min, closest_so_far), temp_rec) do
        {true, temp_rec} ->
          {true, %{rec_acc | t: temp_rec.t, p: temp_rec.p, normal: temp_rec.normal, front_face: temp_rec.front_face, mat: temp_rec.mat}}
          # |> IO.inspect(label: "hit")
        {false, _} ->
          {hit_anything_acc, rec_acc}
      end
    end)

    # {res, rec, _} = Enum.reduce(obj.objects, {hit_anything, rec, closest_so_far}, fn o, {hit_anything_acc, rec_acc, closest_so_far} ->
    #   case Hittable.hit(o, ray, ray_tmin, closest_so_far, temp_rec) do
    #     {true, temp_rec} ->
    #       {true, temp_rec, temp_rec.t}
    #     {false, _} ->
    #       {false, temp_rec, rec_acc}
    #   end
    # end)
    # {res, rec}
  end
end
