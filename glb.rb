require "json"

class GLB
  attr_reader :version, :chunks, :length

  Error = Class.new(StandardError)

  Chunk = Struct.new(:length, :type, :data) do
    def to_s
      "length=#{length}, type=#{type}"
    end
  end

  def initialize(glb_path = ENV["GLB_PATH"])
    @chunks = []
    process_chunks(glb_path)
  end

  def json
    json_chunk = chunks.detect { |chunk| chunk.type == "JSON" }
    JSON.parse(json_chunk.data.strip) if json_chunk
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

  def str_to_uint32(str)
    str.unpack("L").first
  end
end
