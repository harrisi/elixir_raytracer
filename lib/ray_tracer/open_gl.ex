defmodule RayTracer.OpenGL do
  def init do
    do_enables()

    vertices = [
      -1, 1, 0, 1,
      -1, -1, 0, 0,
      1, -1, 1, 0,
      1, 1, 1, 1,
    ] |> Enum.reduce(<<>>, fn el, acc -> acc <> <<el::float-native-size(32)>> end)

    indices = [
      0, 1, 2, 0, 2, 3,
    ] |> Enum.reduce(<<>>, fn el, acc -> acc <> <<el::unsigned-native-size(32)>> end)

    [vao] = :gl.genVertexArrays(1)
    [vbo, ebo] = :gl.genBuffers(2)

    :gl.bindVertexArray(vao)

    :gl.bindBuffer(:gl_const.gl_array_buffer, vbo)
    :gl.bufferData(:gl_const.gl_array_buffer, byte_size(vertices), vertices, :gl_const.gl_static_draw)

    :gl.bindBuffer(:gl_const.gl_element_array_buffer, ebo)
    :gl.bufferData(:gl_const.gl_element_array_buffer, byte_size(indices), indices, :gl_const.gl_static_draw)

    :gl.vertexAttribPointer(0, 2, :gl_const.gl_float, :gl_const.gl_false, 4 * byte_size(<<0::float-size(32)>>), 0)
    :gl.enableVertexAttribArray(0)

    :gl.vertexAttribPointer(1, 2, :gl_const.gl_float, :gl_const.gl_false, 4 * byte_size(<<0::float-size(32)>>), 2 * byte_size(<<0::float-size(32)>>))
    :gl.enableVertexAttribArray(1)

    :gl.bindVertexArray(0)

    [texture] = :gl.genTextures(1)
    :gl.bindTexture(:gl_const.gl_texture_2d, texture)

    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texture_min_filter, :gl_const.gl_linear)
    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texture_mag_filter, :gl_const.gl_linear)

    %{vao: vao, texture: texture}
  end

  defp do_enables do
    # :gl.enable(:gl_const.gl_depth_test)
    # :gl.enable(:gl_const.gl_multisample)
  end
end
