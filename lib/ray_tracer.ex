defmodule RayTracer do
  alias RayTracer.Camera
  alias RayTracer.Mat4
  alias RayTracer.OpenGL
  alias RayTracer.Shader
  alias RayTracer.Vec3
  alias RayTracer.Window

  import RayTracer.WxRecords
  import Bitwise, only: [|||: 2]

  @behaviour :wx_object

  @window_width 1200
  @window_height 800

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
      single: true,
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

    pixels = raytrace_scene(state)

    state = %{state | pixels: pixels}

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
    :wx.batch(fn ->
      render(state)
    end)

    state = update_camera(state)

    {model, view, projection} = create_matrices(state)

    time = :erlang.system_time(:millisecond)

    pixels = raytrace_scene(state)

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
    }

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

    :gl.texImage2D(:gl_const.gl_texture_2d, 0, :gl_const.gl_rgb32f, @window_width, @window_height, 0, :gl_const.gl_rgb, :gl_const.gl_float, pixels)

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

    %{state | camera: %{camera | pos: new_pos}}
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

  defp raytrace_scene(state) do
    IO.inspect(state.dt, label: "previous frame took (ms)")

    x_range = 0..(@window_height - 1)
    y_range = 0..(@window_width - 1)

    if state.single do
      for x <- x_range, y <- y_range, into: <<>> do
        <<x / @window_height::float-native-size(32), y / @window_width::float-native-size(32), 0::float-native-size(32)>>
      end
    else
      x_range
      |> Enum.chunk_every(div(Enum.count(x_range), System.schedulers_online()))
      # I think I can maybe combine this? I don't know.
      |> Task.async_stream(fn x_chunk ->
        for x <- x_chunk, y <- y_range, into: <<>> do
          <<x / @window_height::float-native-size(32), y / @window_width::float-native-size(32), 0::float-native-size(32)>>
        end
      end)
      |> Enum.into(<<>>, fn {:ok, bin} -> bin end)
    end
  end

end
