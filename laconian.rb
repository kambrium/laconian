require 'cgi'
require 'date'
require 'socket'

server = TCPServer.new 'localhost', 1965

loop do
  Thread.start(server.accept) do |client|
    request = client.gets
    puts "#{DateTime.now} #{request}"

    hostname, path, content_length = request.split(" ")

    path = CGI.unescape(path)
    path.slice!(0)

    client.puts("2 text/gemini\r\n")
    file_stream = File.new(path, 'rb')
    IO::copy_stream(file_stream, client)
    file_stream.close

    client.close
  end
end