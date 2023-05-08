require 'cgi'
require 'date'
require 'socket'

root = "."

# def strip_char(string, chars)
#   chars = Regexp.escape(chars)
#   string.gsub(/\A[#{chars}]+|[#{chars}]+\z/, "")
# end

def write_status(client, code, meta)
  client.puts("#{code} #{meta}\r\n")
end

def write_file(client, file_path)
  write_status(client, 2, "text/gemini")
  file_stream = File.new(file_path, 'rb')
  IO::copy_stream(file_stream, client)
  file_stream.close
end

server = TCPServer.new 'localhost', 3000

loop do
  Thread.start(server.accept) do |client|
    request = client.gets
    puts "#{DateTime.now} #{request}"

    hostname, path, content_length = request.split(" ")

    path = CGI.unescape(path)
    # Yes, this is bad! Possible substitution see above.
    cpath = path.chomp("/").reverse.chomp("/").reverse
    file_path = "#{root}/#{cpath}"

    if File.file?(file_path)
      write_file(client, file_path)
    elsif File.directory?(file_path)
      if !path.end_with?("/")
        write_status(client, 3, "#{path}/")
      elsif File.file?("#{file_path}/index.gmi")
        write_file(client, "#{file_path}/index.gmi")
      else
        write_status(client, 2, "text/gemini")
        client.puts("=>..\n")
        Dir.each_child(file_path) {|x| puts "Got #{x}" }
      end
    end

    client.close
  end
end