require("protocol")
require("scheduler")
require("call")
require("node")
require("routing")
require("bencoding")
require("liveliness")
require("datastore")


-- kademlua.lua
-- (C) 2009, Michael Meier

math.randomseed(ec.time())




--print("s1:", s1.readyq)


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
		   call=1}
   local raw = encodepacket(packet)
   packet.raw = raw
   --print("yielding packet")
   coroutine.yield("p", packet)
		   
end

function packethandler()
   while 1 do
      local packet = coroutine.yield("gp")

      print("GOT A PACKET!")
      
      --local rpacket = {to=packet.from, 
	--	rpcid=packet.rpcid, 
	--	fromid="liveshitliveshitxxXX",
	--	call = 128}
      --local rraw = encodepacket(rpacket)
      --print("raw len: " .. #rraw)
      --coroutine.yield("p", {to=packet.from, raw=rraw})

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
   --local c = Channel:new()
   --srun(server)
   --srun(client)
   --srun(hin, c)
   --srun(her, c)
   --srun(packethandler)
   --srun(ping, {addr="192.168.1.5", port=9000})
   --srun(client, "c2")
   --srun(client, "c3")

   io.output():setvbuf("no")

   print("id: " .. ec.tohex(id))

   local node = KademluaNode:new(id)
   srun(node.run, node)
   
   --for i, to in ipairs(bootstrap) do
   --   srun(node.ping, node, to)
   --   --srun(node.findnode, node, to, "das esch de rap shit")
   --end

   -- as there is no mechanism (yet?) to tell when the call manager is ready
   for i=1,10 do syield() end

   -- sleep to wait for all nodes to come up
   ssleep(3.0)

   node:bootstrap(bootstrap)
   --srun(node.bootstrap, node, bootstrap)
   --errorfree, neighbours = scall(node.iterativefindnode, node, ec.sha1(tostring(port)))
   --if errorfree then
   --   for i,neighbour in ipairs(neighbours) do
--	 node:ping(neighbour)
--      end
--   end
   ssleep(0.5)

   node:iterativestore(ec.sha1("das"), "esch de rap shit")
   local ret = node:iterativefindvalue(ec.sha1("das"))
   print("ITERATIVEFINDVALUE: done")
   table.foreach(ret, function(index, what) if type(what) == "table" then print(what.from.addr .. ":" .. what.from.port .. ": " .. tostring(what.retval)) end end)

   srun(printn, 3)

   print("KADEMLUA: " .. tostring(node.callmanager.livelinessmanager:isstronglyalive({addr="127.0.0.1", port=8001})))


   ssleep(8.0)

   --stdout = io.output()
   --outfile = io.open("rtable." .. ec.tohex(id), "w")
   --io.output(outfile)
   --newout = io.output()
   --print(stdout, newout)
   --print("should go to rtable file")
   --io.write("in rtable")
   print("===>")
   node.routingtable:print()
   print("<===")
   --io.flush(outfile)
   --io.output(stdout)
   --xsio.close(outfile)

   local errorfree, ret = scall(f2)
   --srun(client, "c4")
   return "retval f1", ret
end


function yielder()
   while 1 do
      coroutine.yield()
   end
end
resume=coroutine.resume
function bm()
   local y = coroutine.create(yielder)
   local i = 0
   local rs = coroutine.resume

   local t1 = ec.time()
   while i < 1e7 do
      --coroutine.resume(y) -- 4.7s
      --rs(y)               -- 3.9s
      --resume(y)           -- 4.35s
      i = i + 1
   end
   local t2 = ec.time()
   print("diff:", t2-t1)
   os.exit(0)
end

--bm()

--node = KademluaNode:new(id)
s1 = Scheduler:new()
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
