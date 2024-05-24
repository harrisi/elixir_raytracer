defmodule RayTracer.Vec3 do
  @type t :: {float(), float(), float()}

  @spec new() :: t()
  def new() do
    new(0, 0, 0)
  end

  @spec new(x :: number(), y :: number(), z :: number()) :: t()
  def new(x, y, z) do
    {x + 0.0, y + 0.0, z + 0.0}
  end

  @spec add(vec1 :: t(), vec2 :: t()) :: t()
  def add({x1, y1, z1}, {x2, y2, z2}) do
    {x1 + x2, y1 + y2, z1 + z2}
  end

  @spec len(vec :: t()) :: float()
  def len({x, y, z}) do
    :math.sqrt(length_squared({x, y, z}))
  end

  @spec length_squared(vec :: t()) :: number()
  def length_squared({x, y, z}) do
    x * x + y * y + z * z
  end

  @spec cross(vec1 :: t(), vec2 :: t()) :: t()
  def cross({x1, y1, z1}, {x2, y2, z2}) do
    {
      y1 * z2 - z1 * y2,
      z1 * x2 - x1 * z2,
      x1 * y2 - y1 * x2
    }
  end

  @spec dot(vec1 :: t(), vec2 :: t()) :: float()
  def dot({x1, y1, z1}, {x2, y2, z2}) do
    x1 * x2 + y1 * y2 + z1 * z2
  end

  @spec normalize(vec :: t()) :: t()
  def normalize({x, y, z}) do
    sum_of_squares = x * x + y * y + z * z
    len = :math.sqrt(sum_of_squares)
    {x / len, y / len, z / len}
  end

  @spec scale(vec :: t(), scale :: float()) :: t()
  def scale({x, y, z}, scale) do
    {x * scale, y * scale, z * scale}
  end

  @spec subtract(vec1 :: t(), vec2 :: t()) :: t()
  def subtract({x1, y1, z1}, {x2, y2, z2}) do
    {x1 - x2, y1 - y2, z1 - z2}
  end

  @spec negate(v :: t()) :: t()
  def negate({x, y, z}) do
    {-x, -y, -z}
  end

  @spec unit(v :: t()) :: t()
  def unit(v) do
    scale(v, 1 / len(v))
  end

  @spec multiply(v1 :: t(), v2 :: t()) :: t()
  def multiply({x1, y1, z1}, {x2, y2, z2}) do
    new(x1 * x2, y1 * y2, z1 * z2)
  end

  @spec random() :: t()
  def random() do
    new(:rand.uniform(), :rand.uniform(), :rand.uniform())
  end

  @spec random(min :: number(), max :: number()) :: t()
  def random(min, max) do
    new(rand_range(min, max), rand_range(min, max), rand_range(min, max))
  end

  defp rand_range(min, max) do
    min + (max - min) * :rand.uniform()
  end

  def random_in_unit_sphere() do
    do_random_in_unit_sphere(random(-1, 1))
  end

  defp do_random_in_unit_sphere(v) do
    if length_squared(v) < 1 do
      v
    else
      do_random_in_unit_sphere(random(-1, 1))
    end
  end

  def random_unit_vector() do
    unit(random_in_unit_sphere())
  end

  def random_on_hemisphere(normal) do
    on_unit_sphere = random_unit_vector()
    if dot(on_unit_sphere, normal) > 0 do
      on_unit_sphere
    else
      negate(on_unit_sphere)
    end
  end

  @spec near_zero(v :: t()) :: boolean()
  def near_zero({x, y, z}) do
    s = 1.0e-8
    abs(x) < s and abs(y) < s && abs(z) < s
  end

  @spec reflect(v :: t(), n :: t()) :: t()
  def reflect(v, n) do
    v
    |> subtract(scale(n, dot(v, n) * 2))
  end
end
