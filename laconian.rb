require 'cgi'
require 'date'
require 'socket'

class SpartanRequestHandler
  attr_reader :client

  def initialize(client)
    @client = client
  end

  def handle(root)
    request = client.gets
    puts "#{DateTime.now} #{request}"
    hostname, path, content_length = request.split(" ")
    if !path
      raise IOError.new("Not found")
    end

    path = CGI.unescape(path)

    # Guard against breaking out of the directory. Source (accessed 23-05-10):
    # https://practicingruby.com/articles/implementing-an-http-file-server
    clean = []
    parts = path.split("/")
    parts.each do |part|
      next if part.empty? || part == "."
      part == ".." ? clean.pop : clean << part
    end

    file_path = File.join(root, *clean)

    if File.file?(file_path)
      write_file(file_path)
    elsif File.directory?(file_path)
      if !path.end_with?("/")
        write_status(3, "#{path}/")
      elsif File.file?(File.join(file_path, "index.gmi"))
        write_file(File.join(file_path, "index.gmi"))
      else
        write_status(2, "text/gemini")
        write_line("=>..")
        Dir.each_child(file_path) do |child|
          if File.directory?(File.join(file_path, child)) # Can be improved?
            write_line("#{child}/")
          else
            write_line("#{child}")
          end
        end
      end
    else
      raise IOError.new("Not found")
    end

  rescue IOError => e
    write_status(4, e)
  rescue
    write_status(5, "An unexpected error has occurred")
    raise
  end

  def write_line(text)
    client.puts("#{text}\n")
  end

  def write_status(code, meta)
    client.puts("#{code} #{meta}\r\n")
  end

  def write_file(file_path)
    write_status(2, "text/gemini")
    file_stream = File.new(file_path, 'rb')
    IO::copy_stream(file_stream, client)
    file_stream.close
  end
end

root = "."

server = TCPServer.new 'localhost', 3000

loop do
  Thread.start(server.accept) do |client|
    srh = SpartanRequestHandler.new(client)
    srh.handle(root)
    client.close
  end
end