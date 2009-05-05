require("protocol")
require("scheduler")
require("call")

math.randomseed(ec.time())


s1 = Scheduler:new()

print("s1:", s1.readyq)


print("hash of 'kademlua':", ec.tohex(ec.sha1("kademlua")))
print("with fromhex:", ec.tohex(ec.fromhex(ec.tohex(ec.sha1("kademlua")))))

-- this xors
-- 1111 0101 1100 1010 0.....
-- 1111 0011 0000 0011 0.....
-- --------------------------
-- 0000 0110 1100 1001 0.....
--    0    6    c    0 0.....
xorres = ec.xor(ec.fromhex("f5ca0000"), ec.fromhex("f3030000"))
print("xor:", ec.tohex(xorres))
-- seems to be working :P

print("this would be put in bucket " .. tostring(ec.getbucketno(xorres)))
-- seems to be correct too


function f2()
   return "retval f2"
end

function printn(n)
   for i=1,n do
      print("i is now: " .. tostring(i))
      syield()
      ssleep(1.8)
   end
end

function ping(who)
   local rpcid = string.sub(ec.sha1(tostring(math.random())), 1, 8)
   local packet = {to=who,
		   rpcid=rpcid,
		   fromid="pingndidpingndidxxXX",
		   call=129}
   local raw = encodepacket(packet)
   packet.raw = raw
   --print("yielding packet")
   coroutine.yield("p", packet)
		   
end

function packethandler()
   while 1 do
      local packet = coroutine.yield("gp")
      
      local rpacket = {to=packet.from, 
		rpcid=packet.rpcid, 
		fromid="liveshitliveshitxxXX",
		call = 128}
      local rraw = encodepacket(rpacket)
      print("raw len: " .. #rraw)
      coroutine.yield("p", {to=packet.from, raw=rraw})

      --print("PACKET HANDLE CALL", packet)
      --table.foreach(packet.from, print)
      --table.foreach(packet, print)
   end
end


function hin(c)
   local i = 0
   while 1 do
      ssleep(1.0)
      print "hin"
      c:send(i)
      i = i + 1
   end
end

function her(c)
   while 1 do
      local a = c:receive()
      print("her: " .. tostring(a))
   end
end


function server()
   sregister("srv")
   while 1 do
      from, req = swreq()
      print("req from pid " .. tostring(from.pid) .. ":")
      table.foreach(req, print)
      sresp(from, {})
   end
end

function client(name)
   sreq("srv", {a="1", b="2",name=name})
   print(name, "DONE!")
end

function f1()   
   local c = Channel:new()
   srun(server)
   srun(client)
   srun(hin, c)
   srun(her, c)
   srun(packethandler)
   srun(ping, {addr="192.168.1.5", port=9000})
   srun(client, "c2")
   srun(client, "c3")

   srun(printn, 3)
   ssleep(2.0)
   syield()
   local errorfree, ret = scall(f2)
   srun(client, "c4")
   return "retval f1", ret
end
s1:runf(f1, "arg1", "and arg 2")

-- wait for all coroutines to finish
--while(s1:runone() > 0) do print(); print() end
s1:run()

res = ec.getevent()

print("the res table:")
table.foreach(res, print)
print("")
print("res.type: " .. res.type)

if res.type == "stdin" then
   print("from stdin")
elseif res.type == "sock" then
   print("from socket")
   table.foreach(res, print)
   if res.decoded then
      table.foreach(res.message, print)
      print("from:")
      table.foreach(res.message.from, print)
   end
else
   print("unknown from")
end
