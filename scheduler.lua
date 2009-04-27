

-- functions for coroutines being scheduled by Scheduler
function syield()
   coroutine.yield("y")
end


function scall(func, ...)
   if func == nil then
      error("first parameter needs to be a function")
   end
   ret = {coroutine.yield("c", func, ...)}
   return unpack(ret)
end


function srun(func, ...)
   if func == nil then
      error("first parameter needs to be a function")
   end
   ret = {coroutine.yield("r", func, ...)}
   --return unpack(ret)
end





-- the Scheduler implementation
Scheduler = {
}


function Scheduler:new(o)
   o = o or {readyq = {},
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