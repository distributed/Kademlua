

KademluaNode = {}

function KademluaNode:new(id)
   local id = id or ec.sha1(tostring(math.random()))
   local o = {id = id,
	      routingtable = RoutingTable:new(id),
	      rpcdispatch = {["ping"] = self.inping}
	   }
   o.callmanager = CallManager:new(o)


   setmetatable(o,self)
   self.__index = self
   return o
end

function KademluaNode:sendRPC(whom, name, ...)

   if type(name) ~= "string" then error("name needs to be a string", 2) end

   local packet = {to=whom,
		   fromid=self.id,
		   call=1, -- standard
		   payload={name=name, args=arg}
		}

   local rep=sreq("callmanager", packet)
   if rep.reply == true then
      if not rep.payload then error("no payload in received packet?") end
   else
      if not rep.reply == false then error("reply field not set") end
      -- so there is something to unpack
      rep.payload = {}
   end

   print("reply from callmanager")
   table.foreach(rep,print)
   
   return rep.reply, unpack(rep.payload)
end

function KademluaNode:incomingRPC(packet)
   local payload = packet.payload
   if not (type(payload) == "table") then return end
   if not (type(payload.name) == "string") then return end
   if not (type(payload.args) == "table") then return end

   local func = self.rpcdispatch[payload.name]
   local ret = {func(unpack(payload.args))}
   
   local retpacket = {to=packet.from,
		      fromid=self.id,
		      rpcid=packet.rpcid,
		      call=129,
		      payload=ret
		   }
   table.foreach(retpacket, print)
   print("ret")
   return {retpacket}
end


function KademluaNode:ping(who)

   --local rpcid = string.sub(ec.sha1(tostring(math.random())), 1, 8)
   --local packet = {to=who,
--		   fromid=self.id,
--		   payload={name="ping", args={}},
--		   call=1}
   --local raw = encodepacket(packet)
   --packet.raw = raw
   --print("yielding packet")
   --coroutine.yield("p", packet)
   print("PING REQUEST")
   --rets = {sreq("callmanager", packet)}
   rets = {self:sendRPC(who, "ping")}
   print("PING TO " .. who.addr .. ":" .. who.port)  
   table.foreach(rets, print)
   print("----")
end

function KademluaNode:inping()

   print("INPING")
   

   
   --local outpack = {call=129, 
--		    rpcid=packet.rpcid,
--		    fromid=self.id,
--		    to=packet.from}
   --local rraw = encodepacket(outpack)
   --outpack.raw = rraw
   print("~~~~~~~~~ PONG!")
   
   return 5
end


function KademluaNode:run()
   srun(self.callmanager.outgoingloop, self.callmanager)
   srun(self.callmanager.incomingloop, self.callmanager)
end