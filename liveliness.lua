
-- liveliness.lua
-- (C) 2009 Michael Meier


--
-- SECURITY: please note that the current mechanism for dealing with
-- incomplete contacts (missing unique) is very primitive and not
-- robust. it does handle the case in which a known socket may refer
-- to multiple uniques.
--


-- the current handling of active probes is very shake and probably a
-- source of many funny and interesting race conditions. you have been
-- warned.


LivelinessManager = {}


function LivelinessManager:new(node)
   local o = {
      byunique = {},
      bysocket = {},
      node = node,
      maxretry = 3
	  }

   if node == nil then error("LivelinessManager needs a node") end

   setmetatable(o,self)
   self.__index = self
   return o
end


function LivelinessManager:findwatchdog(contact)
   local watchdog

   local socket = contact.addr .. "|" .. tostring(contact.port)
   if contact.unique then
      watchdog = self.byunique[contact.unique]

      if watchdog then
	 self.bysocket[socket] = watchdog
      else
	 watchdog = self.bysocket[socket]
	 if watchdog then
	    self.byunique[contact.unique] = watchdog
	 end
      end
   else
      watchdog = self.bysocket[contact.addr .. "|" .. tostring(contact.port)]
   end
   
   return watchdog
end


function LivelinessManager:newwatchdog(contact)
   local eventpipe = Channel:new()
   local contact = {addr=contact.addr,
		    port=contact.port,
		    id=contact.id,
		    unique=contact.unique
		 }

   local socket = contact.addr .. "|" .. tostring(contact.port)

   local rpcsrunning = {}
   local waitingclients = {}
   local numwaitingclients = 0
   local probing = false
   local probingstep = 0

   local lastin = 0
   local stopprobing = false

   local function updatecontact(newcontact)
      if not contact.unique and newcontact.unique then
	 contact.unique = newcontact.unique
      end
   end
   

   local function probebackoff(step)
      local base = timeout * (2 ^ step)
      local jitter = (math.random() * base) / 2
      
      return base + jitter
   end


   local function probe()
      probingstep = 0
      probing = true

      local lastinatstart = lastin
      
      print("LIVELINESS: starting probe for " .. socket)

      while probingstep < self.maxretry do
	 if stopprobing then 
	    stopprobing = false
	    probing = false
	    return 
	 end

	 print("LIVELINESS: probing step " .. probingstep .. " @ " .. socket)
	 local errorfree = self.node:ping(contact)

	 if stopprobing then 
	    probing = false
	    stopprobing = false
	    return
	 end
	 
	 if errorfree then 
	    print("LIVELINESS: probing step " .. tonumber(probingstep) .. " @ " .. socket .. " OK")
	    probing = false
	    eventpipe:send("probereply", contact)
	    probing = false
	    stopprobing = false
	    return
	 else
	    probingstep = probingstep + 1
	    local oldlastin = lastin
	    eventpipe:send("probetimeout", contact, probingstep)
	    print("LIVELINESS: probing step " .. tonumber(probingstep - 1) .. " @ " .. socket .. " TIMEOUT")
	    ssleep(probebackoff(probingstep))

	    if lastin > oldlastin then
	       probing = false
	       stopprobing = false
	       return
	    end
	 end
      end
      
      probing = false
      stopprobing = false
   end

   local function watchdog()

      print("LIVELINESS: starting watchdog for " .. socket)

      while true do
	 local msg, contact, rpcid = eventpipe:receive()
	 
	 local now = ec.time()

	 if msg == "out" then
	    print("LIVELINESS: outgoing packet to " .. socket .. " >")
	    updatecontact(contact)

	    rpcsrunning[rpcid] = {rpcid=rpcid,
				  when=now}
	 elseif msg == "in" then
	    updatecontact(contact)
	    print("LIVELINESS: updating lastin of " .. socket .. " <")
	    lastin = now
	    rpcsrunning[rpcid] = nil

	    stopprobing = true

	    -- notify all the waiting clients that the contact is alive
	    for name, val in pairs(waitingclients) do
	       val.retpipe:send(true)
	    end
	    waitingclients = {}
	    numwaitingclients = 0

	 elseif msg == "timeout" then
	    -- timeout should not yield information about unique
	    local runningt = rpcsrunning[rpcid]
	    if not runningt then print("LIVELINESS: WARNING: timeout with no corresponding entry in rpcsrunning") end
	    rpcsrunning[rpcid] = nil

	 elseif msg == "isweak" then
	    local args = rpcid
	    local timediff = args.timediff
	    local retpipe = args.retpipe

	    if (now - timediff) <= lastin then
	       retpipe:sendasync(true)
	    else
	       retpipe:sendasync(false)
	    end

	 elseif msg == "isstrong" then
	    local args = rpcid
	    numwaitingclients = numwaitingclients + 1
	    waitingclients[args] = args
	    
	    local func, v, p = pairs(rpcsrunning)
	    local firstname, firstval = func(v,p)

	    if not probing then
	       stopprobing = false
	       srun(probe)
	    end

	 elseif msg == "probetimeout" then
	    local stepattimeout = rpcid
	    
	    if stepattimeout >= self.maxretry then
	       for name, clientt in pairs(waitingclients) do
		  clientt.retpipe:send(false)
	       end

	       waitingclients = {}
	       numwaitingclients = 0
	    end
	    
	 elseif msg == "die" then
	    return
	 end
      end
   end


   srun(watchdog)
   
   local watchdogstruct = {eventpipe=eventpipe,
			   lastcomm=0
			  }
   if contact.unique then
      self.byunique[contact.unique] = watchdogstruct
   end

   local socket = contact.addr .. "|" .. tostring(contact.port)
   self.bysocket[socket] = watchdogstruct

   return watchdogstruct
end


function LivelinessManager:outcomm(contact, rpcid)
   local watchdog = self:findwatchdog(contact) or self:newwatchdog(contact)

   watchdog.eventpipe:sendasync("out", contact, rpcid)
   watchdog.lastcomm = ec.time()
end


function LivelinessManager:incomm(contact, rpcid)
   local watchdog = self:findwatchdog(contact) or self:newwatchdog(contact)

   watchdog.eventpipe:sendasync("in", contact, rpcid)
   watchdog.lastcomm = ec.time()
end


function LivelinessManager:timeout(contact, rpcid)
   local watchdog = self:findwatchdog(contact)

   if watchdog then
      watchdog.eventpipe:sendasync("timeout", contact, rpcid)
      watchdog.lastcomm = ec.time()
   end

   --if not watchdog then
   --   print("LIVELINESS: ERROR: timeout with no corresponding watchdog")
   --end
end


function LivelinessManager:isweaklyalive(contact, timeframe)
   local timeframe = timeframe or 10
   local watchdog = self:findwatchdog(contact)

   if watchdog then
      local args = {timediff=timeframe,
		    retpipe=Channel:new()}
      watchdog.eventpipe:sendasync("isweak", contact, args)
      return args.retpipe:receive()
   else
      return false
   end
end



function LivelinessManager:isstronglyalive(contact)
   local watchdog = self:findwatchdog(contact) or self:newwatchdog(contact)

   local args = {retpipe=Channel:new()}
   watchdog.eventpipe:sendasync("isstrong", contact, args)
   return args.retpipe:receive()
end