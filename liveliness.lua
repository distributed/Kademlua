
-- liveliness.lua
-- (C) 2009 Michael Meier


--
-- SECURITY: please note that the current mechanism for dealing with
-- incomplete contacts (missing unique) is very primitive and not
-- robust. it does handle the case in which a known socket may refer
-- to multiple uniques.
--



LivelinessManager = {}


function LivelinessManager:new(node)
   local o = {
      byunique = {},
      bysocket = {},
      node = node
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

   local function updatecontact(newcontact)
      if not contact.unique and newcontact.unique then
	 contact.unique = newcontact.unique
      end
   end

   local function watchdog()
      local lastin = 0

      print("LIVELINESS: starting watchdog for " .. socket)

      while true do
	 local msg, contact, rpcid = eventpipe:receive()
	 
	 local now = ec.time()

	 if msg == "out" then
	    print("LIVELINESS: outgoing packet to " .. socket .. " >")
	    updatecontact(contact)
	 elseif msg == "in" then
	    updatecontact(contact)
	    print("LIVELINESS: updating lastin of " .. socket .. " <")
	    lastin = now
	 elseif msg == "timeout" then
	    -- timeout should not yield information about unique
	 elseif msg == "isweak" then
	    local args = rpcid
	    local timediff = args.timediff
	    local retpipe = args.retpipe

	    if (now - timediff) <= lastin then
	       retpipe:sendasync(true)
	    else
	       retpipe:sendasync(false)
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
      return retpipe:receive()
   else
      return false
   end
end