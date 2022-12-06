require "json"
require "stringio"

class GLB
  attr_reader :version, :length, :chunks

  Error = Class.new(StandardError)

  Chunk = Struct.new(
    :length,
    :type,
    :data
  )

  def initialize(glb_path = ENV["GLB_PATH"])
    @chunks = []
    process_chunks(glb_path)
  end

  def json
    json_chunk = chunks.detect { |chunk| chunk.type == "JSON" }
    JSON.parse(json_chunk.data.strip) if json_chunk
  end

  def buffers
    chunks.select { |chunk| chunk.type == "BIN\x00" }
  end

  def buffer(index)
    data = buffers[index]&.data
    StringIO.new(data)
  end

  def accessData(accessor_index)
    ac = json["accessors"][accessor_index]
    bv = json["bufferViews"][ac["bufferView"]]
    buff = buffer(bv["buffer"])
    buff.seek(bv["byteOffset"] + ac["byteOffset"])
    bin_data = buff.read(bv["byteLength"])
    convert_data_type(bin_data, ac["componentType"])
  end

  private

  def process_chunks(glb_path)
    file = File.new(glb_path, "r")

    # ref: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.pdf
    magic = file.read(4)
    raise Error, "invalid glTF - magic #{magic}" unless magic == "glTF"

    @version = str_to_uint32(file.read(4))
    @length  = str_to_uint32(file.read(4))

    # 12 byte header is done
    # begin processing chunks
    while not file.eof?
      chunk_length, chunk_type = file.read(4), file.read(4)
      chunk_length = str_to_uint32(chunk_length)
      chunk_data = file.read(chunk_length)
      @chunks << Chunk.new(chunk_length, chunk_type, chunk_data)
    end

    file.close
  end

  def convert_data_type(bin_data, component_type)
    # TODO: lookup the rest of the types
    format =
      case component_type
      when 5126 then "e"
      when 5123 then "S"
      when 5125 then "L"
      else ""; end
    bin_data&.unpack("#{format}*")
  end

  def str_to_uint32(str)
    str.unpack("L").first
  end
end
