defmodule RayTracer do
  alias RayTracer.Lambertian
  alias RayTracer.Sphere
  alias RayTracer.Camera
  alias RayTracer.Mat4
  alias RayTracer.OpenGL
  alias RayTracer.Shader
  alias RayTracer.Vec3
  alias RayTracer.Window
  alias RayTracer.Ray
  alias RayTracer.HittableList
  alias RayTracer.Hittable
  alias RayTracer.HitRecord
  alias RayTracer.Interval
  alias RayTracer.Material
  alias RayTracer.Lambertian
  alias RayTracer.Metal

  import RayTracer.WxRecords
  import Bitwise, only: [|||: 2]

  @behaviour :wx_object

  @window_width 800
  @window_height 450

  def start do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args) do
    window = Window.init(@window_width, @window_height)

    shader_program = Shader.init("shaders/vertex.vs", "shaders/fragment.fs")

    opengl = OpenGL.init()

    state = %{
      shader_program: shader_program,
      keys: %{},
      camera: %Camera{},
      last_x: nil,
      last_y: nil,
      dt: 1,
      t: :erlang.system_time(:millisecond),
      pixels: nil,
      single: false,
    }

    {model, view, projection} = create_matrices(state)

    gl_stuff = %{
      matrices: %{
        model: model,
        view: view,
        projection: projection,
      },
      locations: %{
        model: :gl.getUniformLocation(shader_program, ~c"model"),
        view: :gl.getUniformLocation(shader_program, ~c"view"),
        projection: :gl.getUniformLocation(shader_program, ~c"projection"),
      }
    }

    state = state
    |> Map.merge(window)
    |> Map.merge(opengl)
    |> Map.merge(gl_stuff)

    aspect_ratio = 16 / 9
    image_width = @window_width

    image_height = max(trunc(image_width / aspect_ratio), 1)

    focal_length = 1
    viewport_height = 2
    viewport_width = viewport_height * (image_width / image_height)
    camera_center = Vec3.new(0, 0, 0)

    viewport_u = Vec3.new(viewport_width, 0, 0)
    viewport_v = Vec3.new(0, viewport_height, 0)

    pixel_delta_u = Vec3.scale(viewport_u, 1 / image_width)
    pixel_delta_v = Vec3.scale(viewport_v, 1 / image_height)

    viewport_upper_left = camera_center
                          |> Vec3.subtract(Vec3.new(0, 0, focal_length))
                          |> Vec3.subtract(Vec3.scale(viewport_u, 1/2))
                          |> Vec3.subtract(Vec3.scale(viewport_v, 1/2))

    pixel00_loc = viewport_upper_left
             |> Vec3.add(Vec3.scale(Vec3.add(pixel_delta_u, pixel_delta_v), 1/2))

    mat_ground = Lambertian.new(Vec3.new(0.8, 0.8, 0))
    mat_center = Lambertian.new(Vec3.new(0.1, 0.2, 0.5))
    mat_left = Metal.new(Vec3.new(0.8, 0.8, 0.8))
    mat_right = Metal.new(Vec3.new(0.8, 0.6, 0.2))

    r = %{
      samples_per_pixel: 20,
      image_width: image_width,
      image_height: image_height,
      focal_length: focal_length,
      viewport_height: viewport_height,
      camera_center: camera_center,
      viewport_u: viewport_u,
      viewport_v: viewport_v,
      pixel_delta_u: pixel_delta_u,
      pixel_delta_v: pixel_delta_v,
      viewport_upper_left: viewport_upper_left,
      pixel00_loc: pixel00_loc,
      world: %HittableList{
        objects: [
          Sphere.new(Vec3.new(0, -100.5, -1), 100, mat_ground),
          Sphere.new(Vec3.new(1, 0, -1), 0.5, mat_right),
          Sphere.new(Vec3.new(-1, 0, -1), 0.5, mat_left),
          Sphere.new(Vec3.new(0, 0, -1.2), 0.5, mat_center),
        ]
      },
    }

    state = Map.merge(state, r)

    send(self(), :update)

    {window.frame, state}
  end

  def handle_event(wx(event: wxClose()), state) do
    IO.puts("closing")
    {:stop, :normal, state}
  end

  def handle_event(wx(event: wxKey(type: :key_down, keyCode: key_code)), state) do
    state = %{state | keys: Map.put(state.keys, key_code, true)}

    # if key_code == ?L do
    #   :wxWindow.releaseMouse(state.canvas)
    #   :wxWindow.setCursor(state.canvas, :wx_const.wx_null_cursor())
    # end

    state = if key_code == ?M do
      %{state | single: not(state.single)}
    else
      state
    end

    if key_code == ?E do
      send(self(), :start_profiling)
    end

    {:noreply, state}
  end

  def handle_info(:start_profiling, state) do
    # :tprof.start(%{type: :call_memory})
    # :tprof.enable_trace(:all)
    # :tprof.set_pattern(:_, :_, :_)
    :eprof.start_profiling([self()])
    :eprof.log('eprof')
    Process.send_after(self(), :stop_profiling, 30_000)
    {:noreply, state}
  end

  def handle_info(:stop_profiling, state) do
    # :tprof.disable_trace(:all)
    # sample = :tprof.collect()
    # inspected = :tprof.inspect(sample, :process, :measurement)
    # shell = :maps.get(self(), inspected)

    # IO.puts(:tprof.format(shell))

    :eprof.stop_profiling()
    :eprof.analyze()
    {:noreply, state}
  end

  def handle_event(wx(event: wxKey(type: :key_up, keyCode: key_code)), state) do
    state = %{state | keys: Map.put(state.keys, key_code, false)}

    {:noreply, state}
  end

  def handle_event(wx(event: wxMouse(type: :motion, x: x, y: y)), state) do
    {lx, ly} = unless state.last_x, do: {x, y}, else: {state.last_x, state.last_y}

    sensitivity = state.dt / 100_000
    x_offset = (x - lx) * sensitivity
    y_offset = (ly - y) * sensitivity

    new_yaw = state.camera.yaw + x_offset
    new_pitch = state.camera.pitch + y_offset

    new_pitch =
      cond do
        new_pitch > 89.0 -> 89.0
        new_pitch < -89.0 -> -89.0
        true -> new_pitch
      end

    camera = Camera.point(state.camera, new_pitch, new_yaw)

    state = %{
      state
      | camera: camera,
        last_x: x,
        last_y: y
    }

    {:noreply, state}
  end

  def handle_event(_request, state) do
    {:noreply, state}
  end

  def handle_info(:update, state) do
    time = :erlang.system_time(:millisecond)

    tasks = [
      Task.async(fn -> update_camera(state) end),
      Task.async(fn -> create_matrices(state) end),
      Task.async(fn -> raytrace_scene_rays(state) end),
    ]

    # state = update_camera(state)

    # {model, view, projection} = create_matrices(state)

    # time = :erlang.system_time(:millisecond)

    # pixels = raytrace_scene(state)

    [camera, {model, view, projection}, pixels] = Task.await_many(tasks, :infinity)

    state = %{
      state
      | dt: time - state.t,
        t: time,
        matrices: %{
          model: model,
          view: view,
          projection: projection
        },
        pixels: pixels,
        camera: camera,
    }

    render(state)

    {:noreply, state}
  end

  defp render(%{canvas: canvas} = state) do
    draw(state)
    :wxGLCanvas.swapBuffers(canvas)
    send(self(), :update)
    :ok
  end

  defp draw(%{shader_program: shader_program, vao: vao, texture: texture, pixels: pixels} = state) do
    :gl.clearColor(0.4, 0.5, 0.6, 1.0)
    :gl.clear(:gl_const.gl_color_buffer_bit() ||| :gl_const.gl_depth_buffer_bit())

    :gl.useProgram(shader_program)

    set_uniform_matrix(state.locations.model, state.matrices.model)
    set_uniform_matrix(state.locations.view, state.matrices.view)
    set_uniform_matrix(state.locations.projection, state.matrices.projection)

    :gl.bindTexture(:gl_const.gl_texture_2d, texture)
    :gl.bindVertexArray(vao)

    # :gl.texImage2D(:gl_const.gl_texture_2d, 0, :gl_const.gl_rgb32f, @window_width, @window_height, 0, :gl_const.gl_rgb, :gl_const.gl_float, pixels)
    :gl.texImage2D(:gl_const.gl_texture_2d, 0, :gl_const.gl_rgb, @window_width, @window_height, 0, :gl_const.gl_rgb, :gl_const.gl_unsigned_byte, pixels)

    :gl.drawElements(:gl_const.gl_triangles, 6, :gl_const.gl_unsigned_int, 0)

    :ok
  end

  def update_camera(%{camera: camera, keys: keys} = state) do
    speed = state.dt / 100
    new_pos = camera.pos

    new_pos =
      if Map.get(keys, ?W) do
        Vec3.add(new_pos, Vec3.scale(camera.front, speed))
      else
        new_pos
      end

    new_pos =
      if Map.get(keys, ?S) do
        Vec3.subtract(new_pos, Vec3.scale(camera.front, speed))
      else
        new_pos
      end

    new_pos =
      if Map.get(keys, ?A) do
        Vec3.subtract(
          new_pos,
          Vec3.scale(Vec3.normalize(Vec3.cross(camera.front, camera.up)), speed)
        )
      else
        new_pos
      end

    new_pos =
      if Map.get(keys, ?D) do
        Vec3.add(
          new_pos,
          Vec3.scale(Vec3.normalize(Vec3.cross(camera.front, camera.up)), speed)
        )
      else
        new_pos
      end

    new_pos =
      if Map.get(keys, :wx_const.wxk_space()) do
        Vec3.add(new_pos, Vec3.scale(camera.up, speed))
      else
        new_pos
      end

    new_pos =
      if Map.get(keys, :wx_const.wxk_raw_control()) do
        Vec3.subtract(new_pos, Vec3.scale(camera.up, speed))
      else
        new_pos
      end

    %Camera{camera | pos: new_pos}
  end

  def create_matrices(%{camera: camera}) do
    model = Mat4.identity()
    view = Mat4.look_at(camera.pos, Vec3.add(camera.pos, camera.front), camera.up)
    projection = Mat4.perspective(:math.pi() / 4, @window_width / @window_height, 0.1, 100.0)

    {model, view, projection}
  end

  def set_uniform_matrix(location, matrix) do
    :gl.uniformMatrix4fv(location, :gl_const.gl_false(), [Mat4.flatten(matrix)])
  end

  # defp hit_sphere(center, radius, ray) do
  #   oc = Vec3.subtract(center, ray.origin)
  #   a = Vec3.dot(ray.direction, ray.direction)
  #   b = -2 * Vec3.dot(ray.direction, oc)
  #   c = Vec3.dot(oc, oc) - radius * radius
  #   discriminant = b * b - 4 * a * c
  #   if discriminant < 0 do
  #     -1
  #   else
  #     (-b - :math.sqrt(discriminant)) / (2 * a)
  #   end
  # end

  # defp hit_sphere(center, radius, ray) do
  #   oc = Vec3.subtract(center, ray.origin)
  #   a = Vec3.length_squared(ray.direction)
  #   h = Vec3.dot(ray.direction, oc)
  #   c = Vec3.length_squared(oc) - radius * radius
  #   discriminant = h * h - a * c
  #   if discriminant < 0 do
  #     -1
  #   else
  #     h - :math.sqrt(discriminant) / a
  #   end
  # end

  defp linear_to_gamma(linear_component) do
    if linear_component > 0 do
      :math.sqrt(linear_component)
    else
      0
    end
  end

  defp write_color({r, g, b}) do
    i = Interval.new(0, 1)
      <<
        round(255 * Interval.clamp(i, linear_to_gamma(r))),
        round(255 * Interval.clamp(i, linear_to_gamma(g))),
        round(255 * Interval.clamp(i, linear_to_gamma(b)))
      >>
  end

  defp ray_color(_ray, 0, _world), do: Vec3.new(0, 0, 0)
  defp ray_color(ray, depth, world) do
    {res, rec} = Hittable.hit(world, ray, Interval.new(0.001, :infinity), HitRecord.new())

    if res do
      {res2, attenuation, scattered} = Material.scatter(rec.mat, ray, rec, Vec3.new(), Ray.new())
      if res2 do
        Vec3.multiply(attenuation, ray_color(scattered, depth - 1, world))
      else
        Vec3.new(0, 0, 0)
      end
      # dir = Vec3.add(rec.normal, Vec3.random_unit_vector())
      # Vec3.scale(ray_color(Ray.new(rec.p, dir), depth - 1, world), 0.5)
    else
      {_, y, _} = Vec3.unit(ray.direction)
      a = 0.5 * (y + 1)

      Vec3.scale(Vec3.new(1, 1, 1), 1 - a)
      |> Vec3.add(Vec3.scale(Vec3.new(0.5, 0.7, 1), a))
    end
  end

  defp raytrace_scene(state) do
    IO.inspect(state.dt, label: "previous frame took (ms)")

    x_range = 0..(@window_height - 1)
    y_range = 0..(@window_width - 1)

    if state.single do
      for x <- x_range, y <- y_range, into: <<>> do
        <<round(x / @window_height * 255), round(y / @window_width * 255), 0>>
      end
    else
      x_range
      |> Enum.chunk_every(div(Enum.count(x_range), System.schedulers_online()))
      |> Enum.map(fn x_chunk ->
        Task.async(fn ->
          do_chunk(x_chunk, y_range)
        end)
      end)
      |> Task.await_many(:infinity)
      |> Enum.into(<<>>, fn bin -> bin end)

      # |> Task.async_stream(fn x_chunk ->
      #   do_chunk(x_chunk, y_range)
      # end)
      # |> Enum.into(<<>>, fn {:ok, bin} -> bin end)
    end
  end

  defp raytrace_scene_rays(state) do
    IO.inspect(state.dt, label: "[ray] previous frame took (ms)")

    x_range = 0..(@window_height - 1)
    y_range = 0..(@window_width - 1)

    if state.single do
      for x <- x_range, y <- y_range, into: <<>> do
        # pixel_center = state.pixel00_loc
        # |> Vec3.add(Vec3.scale(state.pixel_delta_u, y))
        # |> Vec3.add(Vec3.scale(state.pixel_delta_v, x))

        # ray_direction = Vec3.subtract(pixel_center, state.camera_center)

        # ray = Ray.new(state.camera_center, ray_direction)

        # ray_color(ray, state.world)
        # |> write_color

        Enum.reduce(0..(state.samples_per_pixel - 1), Vec3.new(0, 0, 0), fn _, acc ->
          {ox, oy, _} = Vec3.new(:rand.uniform() - 0.5, :rand.uniform() - 0.5, 0)

          pixel_sample = state.pixel00_loc
          |> Vec3.add(Vec3.scale(state.pixel_delta_u, oy + y))
          |> Vec3.add(Vec3.scale(state.pixel_delta_v, ox + x))

          ray_direction = Vec3.subtract(pixel_sample, state.camera_center)

          ray = Ray.new(state.camera_center, ray_direction)

          Vec3.add(acc, ray_color(ray, 5, state.world))
        end)
        |> Vec3.scale(1 / state.samples_per_pixel)
        |> write_color
      end
    else
      x_range
      |> Enum.chunk_every(div(Enum.count(x_range), System.schedulers_online()))
      |> Enum.map(fn x_chunk ->
        Task.async(fn ->
          do_ray_chunk(x_chunk, y_range, state)
        end)
      end)
      |> Task.await_many(:infinity)
      |> Enum.into(<<>>, & &1)

    end
  end

  defp do_ray_chunk(x_chunk, y_range, state) do
    for x <- x_chunk, y <- y_range, into: <<>> do
      Enum.reduce(0..(state.samples_per_pixel - 1), Vec3.new(0, 0, 0), fn _, acc ->
        {ox, oy, _} = Vec3.new(:rand.uniform() - 0.5, :rand.uniform() - 0.5, 0)

        pixel_sample = state.pixel00_loc
        |> Vec3.add(Vec3.scale(state.pixel_delta_u, oy + y))
        |> Vec3.add(Vec3.scale(state.pixel_delta_v, ox + x))

        ray_direction = Vec3.subtract(pixel_sample, state.camera_center)

        ray = Ray.new(state.camera_center, ray_direction)

        Vec3.add(acc, ray_color(ray, 10, state.world))
      end)
      |> Vec3.scale(1 / state.samples_per_pixel)
      |> write_color
    end
  end

  defp do_chunk(x_chunk, y_range) do
    for x <- x_chunk, y <- y_range, into: <<>> do
      <<round(x / @window_height * 255), round(y / @window_width * 255), 0>>
    end
  end

end
