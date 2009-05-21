
-- params.lua
-- (C) 2009, Michael Meier

if argv[1] then
   local file = io.open(argv[1])
   if file then
      file = nil
      dofile(argv[1])
   else
      port = tonumber(argv[1]) or 8001
   end
end

port = port or 8001
--id = string.sub(string.rep(tostring(port), 20), 1, 20)
id = id or ec.sha1(tostring(port))

--myaddr = "192.168.1.5"
myaddr = myaddr or "127.0.0.1"

bootstrap = bootstrap or {{addr=myaddr, port=8001},
			  {addr=myaddr, port=8002}}

print("PARAMS: port " .. port .. " myaddr " .. myaddr)