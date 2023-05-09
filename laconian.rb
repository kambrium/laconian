require 'cgi'
require 'date'
require 'socket'

class SpartanRequestHandler
  # Class initialization to be reviewed
  attr_reader :client

  def initialize(client)
    @client = client
  end

  def handle(root)
    request = client.gets
    puts "#{DateTime.now} #{request}"

    hostname, path, content_length = request.split(" ")

    path = CGI.unescape(path)
    # Yes, this is bad! Possible substitution see above.
    cpath = path.chomp("/").reverse.chomp("/").reverse
    file_path = "#{root}/#{cpath}"

    if File.file?(file_path)
      write_file(file_path)
    elsif File.directory?(file_path)
      if !path.end_with?("/")
        write_status(3, "#{path}/")
      elsif File.file?("#{file_path}/index.gmi")
        write_file("#{file_path}/index.gmi")
      else
        write_status(2, "text/gemini")
        write_line("=>..")
        Dir.each_child(file_path) do |child|
          if File.directory?("#{file_path}/#{child}") # Must be improved.
            write_line("#{child}/")
          else
            write_line("#{child}")
          end
        end
      end
    end

    client.close
  end

  # def strip_char(string, chars)
  #   chars = Regexp.escape(chars)
  #   string.gsub(/\A[#{chars}]+|[#{chars}]+\z/, "")
  # end

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
  end
end