

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


function ssleep(howlong)
   if type(howlong) ~= "number" then
      error("parameter must be a number")
   end
   
   local errorfree = coroutine.yield("s", howlong)
end


-- the Scheduler implementation
Scheduler = {
}


function Scheduler:new(o)
   o = o or {readyq = {},
	     sleeping = {},
	     nextpid = 1,
	     procs = {}
	  }
   setmetatable(o,self)
   self.__index = self
   return o
end


function Scheduler:runf(func, ...)

   local coro = coroutine.create(func)
   local pid = self.nextpid

   self.nextpid = self.nextpid + 1
   local proc = {pid=pid, coro=coro}
   self.procs[pid] = proc
   print("started pid " .. tostring(pid))

   table.insert(self.readyq, {proc=proc, args=arg})

end



function Scheduler:callf(func, linkproc, ...)

   local coro = coroutine.create(func)
   local pid = self.nextpid

   self.nextpid = self.nextpid + 1
   local proc = {pid=pid, coro=coro, linkproc=linkproc}
   self.procs[pid] = proc
   print("started pid " .. tostring(pid) .. " linked to " ..linkproc.pid)

   table.insert(self.readyq, {proc=proc, args=arg})

end




function Scheduler:handlecall(callres)
   
if callres[2] == "y" then

      table.insert(self.readyq, {proc=self.running, args={}})

   elseif callres[2] == "c" then

      local linkproc = self.running
      table.remove(callres,1)
      table.remove(callres,1)
      local func = table.remove(callres, 1)
      if func == nil then print("!HAS to be a function") end
      self:callf(func, linkproc, unpack(callres))

   elseif callres[2] == "r" then

      table.remove(callres,1)
      table.remove(callres,1)
      local func = table.remove(callres, 1)
      if func == nil then print("!HAS to be a function") end
      self:runf(func, unpack(callres))
      table.insert(self.readyq, {proc=self.running, args={}})

   elseif callres[2] == "s" then

      local howlong = callres[3]
      local wakeup = ec.time() + howlong
      table.insert(self.sleeping, {proc=self.running, wakeup=wakeup})
      table.sort(self.sleeping, function(a,b) return a.wakeup > b.wakeup end)

   else
      print("unknown call from pid " .. self.running.pid)
   end
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
   print("running " .. tostring(proc.pid))
   local callres = {coroutine.resume(coro, unpack(qentry.args))}
   table.foreach(callres, print)
   print("got back:", coroutine.status(coro))      
   
   print("proc:")
   table.foreach(proc, print)


   local state = coroutine.status(coro)
   if state ~= "dead" then
      self:handlecall(callres)
   else
      if proc.linkproc ~= nil then
	 print("adding linked proc to the ready queue")
	 table.remove(callres, 1)
	 print("linkproc", proc.linkproc)
	 table.foreach(callres, print)
	 table.insert(self.readyq, {proc=proc.linkproc, args=callres})
      end
      print("process with pid " .. tostring(pid) .. " died")
   end

   print("readyq")
   table.foreach(self.readyq, print)
   return #(self.readyq)
end




function Scheduler:wakeupsleepers()
   local now = ec.time()
   
   while 1 do
      print("self.sleeping:")
      table.foreach(self.sleeping, print)
      local first = table.remove(self.sleeping)
      if first ~= nil then
	 
	 if now > first.wakeup then
	    -- it's past wake up time
	    print("waking time")
	    table.insert(self.readyq, {proc=first.proc, args={}})
	 else
	    -- sleep on...
	    print("sleeping on")
	    table.insert(self.sleeping, first)
	    return
	 end

      else
	 return
      end
   end
end


function Scheduler:run()
   while (#(self.readyq) > 0 or #(self.sleeping) > 0) do

      self:wakeupsleepers()
      while (#(self.readyq) > 0) do
	 --print("there are " .. tonumber(#(self.readyq)) .. " ready jobs")
	 print()
	 print()
	 self:runone()
	 self:wakeupsleepers()
      end

      local first = self.sleeping[#(self.sleeping)]
      local timeout
      if first ~= nil then
	 timeout = first.wakeup - ec.time()
      else
	 timeout = 0
      end

      --table.foreach(first, print)
      if timeout ~= 0 then
	 -- there's still something to be done
	 print("getevent with a timeout of " .. tostring(timeout))
	 ec.getevent(timeout)
      else
	 break
      end
   end
end