

KademluaNode = {}

function KademluaNode:new(id)
   local id = id or ec.sha1(tostring(math.random()))
   local o = {id=id
        }


   setmetatable(o,self)
   self.__index = self
   return o
end


function KademluaNode:ping(who)
   local rpcid = string.sub(ec.sha1(tostring(math.random())), 1, 8)
   local packet = {to=who,
		   rpcid=rpcid,
		   fromid=self.id,
		   call=1}
   local raw = encodepacket(packet)
   packet.raw = raw
   --print("yielding packet")
   coroutine.yield("p", packet)
		   
end

function KademluaNode:inping(packet)

   print("INPING")
   
   local outpack = {call=129, 
		    rpcid=packet.rpcid,
		    fromid=self.id,
		    to=packet.from}
   local rraw = encodepacket(outpack)
   outpack.raw = rraw
   print("~~~~~~~~~ PONG! len " .. tostring(#outpack.raw) .. " " .. self.id)
   
   return {outpack}
end