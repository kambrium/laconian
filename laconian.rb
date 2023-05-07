require 'cgi'
require 'date'
require 'socket'

root = "."

# def strip_char(string, chars)
#   chars = Regexp.escape(chars)
#   string.gsub(/\A[#{chars}]+|[#{chars}]+\z/, "")
# end

def write_file(client, file_path)
  client.puts("2 text/gemini\r\n")
  file_stream = File.new(file_path, 'rb')
  IO::copy_stream(file_stream, client)
  file_stream.close
end

server = TCPServer.new 'localhost', 1965

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
        client.puts("3 #{path}/\r\n")
      elsif File.file?("#{file_path}/index.gmi")
        write_file(client, "#{file_path}/index.gmi")
      else
        client.puts("2 text/gemini\r\n")
        client.puts("=>..\n")
        Dir.each_child(file_path) {|x| puts "Got #{x}" }
      end
    end

    client.close
  end
end