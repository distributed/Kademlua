

-- functions for coroutines being scheduled by Scheduler
function syield()
   coroutine.yield("y")
end


function scall(func, ...)
   if func == nil then
      error("first parameter needs to be a function")
   end
   local ret = {coroutine.yield("c", func, ...)}
   return unpack(ret)
end


function srun(func, ...)
   if func == nil then
      error("first parameter needs to be a function")
   end
   local ret = {coroutine.yield("r", func, ...)}
   --return unpack(ret)
end

function spacket(packet)
   if not type(packet) == "table" then error("need a packet") end
   coroutine.yield("p", packet)
end


function ssleep(howlong)
   if type(howlong) ~= "number" then
      error("parameter must be a number")
   end
   
   local errorfree = coroutine.yield("s", howlong)
end


function sregister(name)
   if name == nil then error("name has to be given") end
   return coroutine.yield("reg", name)
end


function sreq(nameorpid, req)
   local t = type(nameorpid)
   if t ~= "string" and t ~= number then error("first parameter has to be name or pid") end
   if type(req) ~= "table" then error("req has to be a table") end

   return coroutine.yield("req", nameorpid, req)
end



function swreq()
   local req, from = coroutine.yield("wreq")
   return req, from
end


function sresp(to, resp)
   if not type(to) == "table" then error("to needs to be a proc table") end
   if not to.pid then error("to needs to be a proc table, with a pid") end
   if not type(resp) == "table" then error("the response needs to be a table") end
   coroutine.yield("resp", to, resp)
end



function runcall(packet)
   errorfree, retpack = scall(handlecall, packet)

   --print("runcall errorfree, retpack:", errorfree, retpack)

   coroutine.yield("p", retpack)
end


function handlecall(packet)
   --print "----------------------------"
   --table.foreach(packet.from, print)
   --print("=====")
   --table.foreach(packet, print)

   return {to=packet.from, raw="handlecall generated packet"}
end




Deque = {}
function Deque:new ()
   local o = {first = 0, last = -1}

   setmetatable(o,self)
   self.__index = self
   return o
end


function Deque.pushleft (list, value)
   local first = list.first - 1
   list.first = first
   list[first] = value
end

function Deque.pushright (list, value)
   local last = list.last + 1
   list.last = last
   list[last] = value
end

function Deque.popleft (list)
   local first = list.first
   if first > list.last then error("list is empty") end
   local value = list[first]
   list[first] = nil        -- to allow garbage collection
   list.first = first + 1
   return value
end

function Deque.popright (list)
   local last = list.last
   if list.first > last then error("list is empty") end
   local value = list[last]
   list[last] = nil         -- to allow garbage collection
   list.last = last - 1
   return value
end

function Deque.length(list)
   return list.last - list.first + 1
end





Channel = {
}

function Channel:new()
   local o = { sending = Deque:new(),
	       receiving = Deque:new()
	    }

   setmetatable(o,self)
   self.__index = self
   return o
end

function Channel:send(...)
   --print(args)
   coroutine.yield("cs", self, arg)
end

function Channel:receive()
   ret = {coroutine.yield("cr", self)}
   --table.remove(ret, 1)
   return unpack(ret)
end




-- the Scheduler implementation
Scheduler = {
}



function Scheduler:new(node)
   local o ={ readyq = {},
	      sleeping = {},
	      packetq = {},
	      nextpid = 1,
	      numrunning = 0,
	      procs = {},
	      names={},
	      node=node
	   }
   --o.callmanager= CallManager:new(o, node)

   setmetatable(o,self)
   self.__index = self
   print(o)
   print("--- foreach ---")
   table.foreach(o, print)
   print("--- end ---")
   local dispatch = {y = self.handleyield,
		     c = self.handlecall,
		     r = self.handlerun,
		     s = self.handlesleep,
		     p = self.handlepacket,
		     cs = self.handlechannelsend,
		     cr = self.handlechannelreceive,
		     req = self.handlereq,
		     wreq = self.handlewreq,
		     resp = self.handleresp,
		     reg = self.handlereg,
		     gp = self.handlegetpackets
		  }
		     
   o.dispatch = dispatch
   return o
end


function Scheduler:runf(func, ...)

   local coro = coroutine.create(func)
   local pid = self.nextpid

   self.nextpid = self.nextpid + 1
   local proc = {pid=pid, coro=coro, names={}, reqq={}}
   self.procs[pid] = proc
   --print("started pid " .. tostring(pid))

   table.insert(self.readyq, {proc=proc, args=arg})

   self.numrunning = self.numrunning + 1

end



function Scheduler:callf(func, linkproc, ...)

   local coro = coroutine.create(func)
   local pid = self.nextpid

   self.nextpid = self.nextpid + 1
   local proc = {pid=pid, coro=coro, linkproc=linkproc, names={}, reqq={}}
   self.procs[pid] = proc
   --print("started pid " .. tostring(pid) .. " linked to " ..linkproc.pid)

   table.insert(self.readyq, {proc=proc, args=arg})

   self.numrunning = self.numrunning + 1

end




--function Scheduler:handlecall(callres)
   
function Scheduler:handleyield(callres)
   table.insert(self.readyq, {proc=self.running, args={}})
end


function Scheduler:handlecall(callres)
   local linkproc = self.running
   table.remove(callres,1)
   table.remove(callres,1)
   local func = table.remove(callres, 1)
   if func == nil then print("!HAS to be a function") end
   self:callf(func, linkproc, unpack(callres))
end

function Scheduler:handlerun(callres)
   table.remove(callres,1)
   table.remove(callres,1)
   local func = table.remove(callres, 1)
   if func == nil then print("!HAS to be a function") end
   self:runf(func, unpack(callres))
   table.insert(self.readyq, {proc=self.running, args={}})
end

function Scheduler:handlesleep(callres)
   local howlong = callres[3]
   local wakeup = ec.time() + howlong
   table.insert(self.sleeping, {proc=self.running, wakeup=wakeup})
   table.sort(self.sleeping, function(a,b) return a.wakeup > b.wakeup end)
end

function Scheduler:handlepacket(callres)
   local packet = callres[3]
   --table.insert(self.packetq, packet)
   --table.insert(self.readyq, {proc=self.running, args={}})
   --self.callmanager:outgoing(self.running, packet)
   table.insert(self.packetq, packet)
   table.insert(self.readyq, {proc=self.running, args={}})
end

function Scheduler:handlechannelsend(callres)
   local channel = callres[3]
   local args = callres[4] or {}
   
   
   if channel.receiving:length() > 0 then
      receiver = channel.receiving:popleft()
      table.insert(self.readyq, {proc=receiver.proc, args=args})
      table.insert(self.readyq, {proc=self.running, args={}})
   else
      channel.sending:pushright({proc=self.running, args=args})
   end
   
end

function Scheduler:handlechannelreceive(callres)
   local channel = callres[3]
   
   if channel.sending:length() > 0 then
      sender = channel.sending:popleft()
      table.insert(self.readyq, {proc=self.running, args=sender.args})
      table.insert(self.readyq, {proc=sender.procs, args={}})
   else
      channel.receiving:pushright({proc=self.running, args=callres})
   end
end


function Scheduler:handlereq(callres)
   local nameorpid = callres[3]
   local req = callres[4]
   local pid
   local proc = false
   if type(nameorpid) == "number" then
      pid = nameorpid
      proc = self.procs[pid]
   else
      proc = self.names[nameorpid]
      if proc == nil then
	 table.insert(self.readyq, {proc=self.running, args={false}})
	 return
      end
      pid = proc.pid
      print(proc,pid)
   end
   
   if proc.waitingforreq then
      proc.waitingforreq = nil
      table.insert(self.readyq, {proc=proc, args={self.running, req}})
   else
      print("filling reqq")
      table.insert(proc.reqq, {proc=self.running, req=req})
   end
end
   
   
function Scheduler:handlewreq(callres)
   local running = self.running
   if #(running.reqq) > 0 then
      local reqt = table.remove(running.reqq, 1)
      table.insert(self.readyq, {proc=running, args={reqt.proc, reqt.req}})
   else
      running.waitingforreq = true
   end
end


function Scheduler:handleresp(callres)
   local to = callres[3]
   local resp = callres[4]
   print("type of resp: " .. type(resp))
   if not (to and resp) then
      print("BAD resp CALL, here it goes:")
      print("to:")
      table.foreach(to, print)
      print()
      print("resp:")
      table.foreach(resp, print)
      error("BAD RESP", 3)
   else
      table.insert(self.readyq, {proc=to, args={resp}})
   end
   table.insert(self.readyq, {proc=self.running, args={}})
end

function Scheduler:handlereg(callres)
   local name = callres[3]
   
   table.insert(self.running.names, name)
   self.names[name] = self.running
   table.insert(self.readyq, {proc=self.running, args={}})
end

function Scheduler:handlegetpackets(callres) 
   if self.waitingforpacketproc ~= nil then error("we already have a proc handling packets") end
   self.waitingforpacketproc = self.running
end

function Scheduler:handleunknown(callres)
   print("unknown call from pid " .. self.running.pid)
end


function Scheduler:runone()
   local qentry = table.remove(self.readyq, 1)
   if qentry == nil then return end

   --print("qentry:")
   --table.foreach(qentry, print)

   local proc = qentry.proc
   local coro = proc.coro
   local pid = proc.pid

   self.running = proc
   --print("running " .. tostring(proc.pid))
   local callres = {coroutine.resume(coro, unpack(qentry.args))}
   --table.foreach(callres, print)
   --print("got back:", coroutine.status(coro))      
   
   --print("proc:")
   --table.foreach(proc, print)

   if callres[1] == false then
      print("ERROR: " .. callres[2])
   end

   local state = coroutine.status(coro)
   if state ~= "dead" then
      --self:handlecall(callres)
      local dispatchfunc = self.dispatch[callres[2]]
      if dispatchfunc == nil then
	 print("NO CALL DISPATCHER FOUND FOR " .. tostring(callres[2]))
      else
	 dispatchfunc(self, callres)
      end
   else
      self.numrunning = self.numrunning - 1
      self.procs[pid] = nil
      -- delete registered names
      for i, name in ipairs(proc.names) do
	 self.names[name] = nil
      end
      --print("numrunning: " .. self.numrunning)
      if proc.linkproc ~= nil then
	 --print("adding linked proc to the ready queue")
	 --table.remove(callres, 1)
	 --print("linkproc", proc.linkproc)
	 --table.foreach(callres, print)
	 table.insert(self.readyq, {proc=proc.linkproc, args=callres})
      end
      --print("process with pid " .. tostring(pid) .. " died")
   end

   --print("readyq")
   --table.foreach(self.readyq, print)
   return #(self.readyq)
end




function Scheduler:wakeupsleepers()
   local now = ec.time()
   
   while 1 do
      --print("self.sleeping:")
      --table.foreach(self.sleeping, print)
      local first = table.remove(self.sleeping)
      if first ~= nil then
	 
	 if now > first.wakeup then
	    -- it's past wake up time
	    --print("waking time")
	    table.insert(self.readyq, {proc=first.proc, args={}})
	 else
	    -- sleep on...
	    --print("sleeping on")
	    table.insert(self.sleeping, first)
	    return
	 end

      else
	 return
      end
   end
end


function Scheduler:run()
   --while (#(self.readyq) > 0 or #(self.sleeping) > 0) do
   while self.numrunning > 0 do

      self:wakeupsleepers()
      while (#(self.readyq) > 0) do
	 --print("there are " .. tonumber(#(self.readyq)) .. " ready jobs")
	 self:runone()
	 self:wakeupsleepers()
      end

      local first = self.sleeping[#(self.sleeping)]
      local timeout
      if first ~= nil then
	 timeout = first.wakeup - ec.time()
	 if timeout < 0 then timeout = 0 end
      else
	 timeout = 0
      end

      --table.foreach(first, print)
      --if timeout ~= 0 then
	 -- there's still something to be done
	 --print("getevent with a timeout of " .. tostring(timeout))
	
	 --uepack = {fromid="das esch de rap shit", rpcid="deadbeef", call=2}
	 -- encode packet from table, header version 1
	 --rawpack = encodepacket(uepack, 1)
	 -- 2 packets prepared
	 --packets = {{to={addr="192.168.1.5", port=4501}},
	 --	    {to={addr="78.46.82.237", port=6002}, raw=rawpack}}
	 --	    --{to={addr="78.46.82.237", port=32769}, raw="rap shit"}}
      --print("ec.getevent, timeout " .. timeout .. " & handlepacketproc " .. tostring(self.handlepacketproc))
	 retval = ec.getevent(timeout, self.packetq)
	 self.packetq = {}
	 if retval ~= nil and retval.type == "sock" then
	    --decodepacket(retval)

	    --self.callmanager:incoming({retval})
	    -- srun doesn't work because we can't yield to ourself
	    -- srun(runcall, retval)
	    --self:runf(runcall, retval)

	    local wp = self.waitingforpacketproc
	    if wp then
	       table.insert(self.readyq, {proc=wp, args={{retval}}})
	    end
	    self.waitingforpacketproc = nil
	 end
      --else
	 --break
      --end
   end
   print("end numrunning " .. self.numrunning)
end