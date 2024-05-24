defmodule RayTracer.Interval do
  defstruct [min: :infinity, max: :neg_infinity]

  def new() do
    %__MODULE__{}
  end

  def new(min, max) do
    %__MODULE__{min: min, max: max}
  end

  def size(%__MODULE__{min: min, max: max}) when is_number(min) and is_number(max) do
    max - min
  end

  def size(%__MODULE__{min: min, max: max}) do
    case {min, max} do
      {:neg_infinity, :neg_infinity} -> :neg_nan
      {:neg_infinity, :infinity} -> :neg_infinity
      {:infinity, :infinity} -> :neg_nan
      {:infinity, :neg_infinity} -> :infinity
    end
  end

  defp compare(:infinity, :neg_infinity), do: :gt
  defp compare(:infinity, number) when is_number(number), do: :gt
  defp compare(:neg_infinity, :infinity), do: :lt
  defp compare(:neg_infinity, number) when is_number(number), do: :lt
  defp compare(number, :infinity) when is_number(number), do: :lt
  defp compare(number, :neg_infinity) when is_number(number), do: :gt
  defp compare(a, b) when is_number(a) and is_number(b) do
    case a - b do
      0 -> :eq
      n when n > 0 -> :gt
      _ -> :lt
    end
  end

  defp le(a, b) do
    res = compare(a, b)
    res == :lt or res == :eq
  end

  defp lt(a, b) do
    compare(a, b) == :lt
  end

  defp ge(a, b) do
    res = compare(a, b)
    res == :gt or res == :eq
  end

  defp gt(a, b) do
    compare(a, b) == :gt
  end

  defp eq(a, b) do
    compare(a, b) == :eq
  end

  defp ne(a, b) do
    not(eq(a, b))
  end

  def contains(%__MODULE__{min: min, max: max}, x) do
    le(min, x) and le(x, max)
    # min <= x and x <= max
  end

  def surrounds(%__MODULE__{min: min, max: max}, x) do
    lt(min, x) and lt(x, max)
    # min < x and x < max
  end

  def clamp(%__MODULE__{min: min, max: max}, x) do
    cond do
      lt(x, min) -> min
      gt(x, max) -> max
      true -> x
    end
  end

  def empty do
    new()
  end

  def universe do
    new(:neg_infinity, :infinity)
  end
end
