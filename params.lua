
-- params.lua
-- (C) 2009, Michael Meier

port = tonumber(argv[1]) or 8001
--id = string.sub(string.rep(tostring(port), 20), 1, 20)
id = ec.sha1(tostring(port))

myaddr = "192.168.1.5"

bootstrap = {{addr=myaddr, port=8001},
	     {addr=myaddr, port=8002}}

