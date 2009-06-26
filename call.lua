
-- call.lua
-- (C) 2009 Michael Meier

--timeout = 3600.314159
timeout = 3.1415
timeout = 4.1415
timeout = 1.5
CallManager = {}




function CallManager:new(node)
   local o = {running = {},
	      scheduler = scheduler,
	      node = node,
	      ownid = node.id,
	      routingtable = node.routingtable,
	      livelinessmanager = LivelinessManager:new(node)
	  }
   if o.ownid == nil then error("need an ID",2) end
   if type(o.routingtable) ~= "table" then error("need a routing table in the node") end
   setmetatable(o,self)
   self.__index = self
   return o
end


function CallManager:timeoutf(rpcid, howsoon) 
   ssleep(howsoon)
   if self.running[rpcid] ~= nil then
      -- call timed out
      print("CALL TIMED OUT")
      local runningt = self.running[rpcid]
      self.running[rpcid] = nil

      self.livelinessmanager:timeout(runningt.packet.to, rpcid)

      sresp(runningt.proc, {reply=false, cause="timeout"})
      --table.insert(self.scheduler.readyq, {proc=runningt.proc, args={false}})
   else
      -- do nothing ...
   end
end


function CallManager:incomingloop()
   while 1 do
      local packets = coroutine.yield("gp")
      local validpacks = {}
      local insert = table.insert
      for i, pack in ipairs(packets) do
	 decodepacket(pack)
	 if pack.decoded then
	    insert(validpacks, pack)
	 end
      end
      --print("INCOMING PACKETS")
      --table.foreach(packets, print)
      
      for i, validpack in ipairs(validpacks) do
	 srun(self.incoming, self, {validpack})
      end
      --self:incoming(packets)
   end
end

function CallManager:incoming(packets)
   for i, packet in ipairs(packets) do
      --table.foreach(packet, print)
      local rpcid = packet.rpcid
      local from = packet.from
      --table.foreach(packet, print)
      --if packet.from ~= nil then
      --   print("from")
      --  table.foreach(packet.from,print)
      --end

      print("CALL: packet from " .. packet.from.addr .. ":" 
	    .. packet.from.port ..
	    ":" .. ec.tohex(packet.from.id) 
	     .. " rpcid " ..	 ec.tohex(rpcid))

      -- prevent loopback
      if rpcid ~= self.ownid then
	 --table.foreach(self.running, print)
	 self.routingtable:seenode(packet.from)

	 if self.running[rpcid] ~= nil then
	    local callt = self.running[rpcid]
	    local incall = packet.call
	    if (incall == callt.packet.call + 128) or
	       (incall == 130) or
	       (incall == 131) then

	       local to = callt.packet.to
	       if (to.addr == from.addr) and (to.port == from.port) then
		  if (to.id == nil) or (from.id == to.id) then
		     -- we initiated that call
		     print("CALL: incoming response, rpc id " .. ec.tohex(rpcid))
		     self.livelinessmanager:incomm(packet.from, rpcid)
		     self.running[rpcid] = nil
		     local reply = {payload=packet.payload,
				    from=from,
				    error=false}
		     if packet.call == 130 then
			reply.reply = false
			reply.cause = "notfound"
		     elseif packet.call == 131 then
			reply.reply = false
			reply.cause = "error"
		     else
			reply.reply = true
		     end

		     sresp(callt.proc, reply)
		     --table.insert(self.scheduler.readyq, {proc=callt.proc, args={}})
		  else
		     print ("CALL: callers ID does not match")
		  end
	       else
		  print("CALL: IP/port does not match")
		  print("CALL: from:")
		  table.foreach(from, print)
		  print("CALL: to:")
		  table.foreach(to, print)
	       end
	    else
	       print("CALL: incoming call does not match outgoing call")
	    end
	 else
	    if packet.call < 128 then
	       print("CALL: incoming call")
	       --if packet.call == 1 then
	       --  outpacks = self.node:inping(packet)
	       --end
	       local outpacks = self.node:incomingRPC(packet)
	       for i, pack in ipairs(outpacks) do
		  local raw = encodepacket(pack)
		  pack.raw = raw
		  spacket(pack)
		  --table.insert(self.scheduler.packetq, pack)
	       end
	    else
	       print("CALL: incoming call's rpcid does not match")
	    end
	    -- we did not
	 end
      end
   end
end


function CallManager:outgoing(proc, packet)
   
   local rpcid = string.sub(ec.sha1(tostring(math.random())), 1, 8)
   --rpcid = "64bitqnt"
   
   packet.rpcid = rpcid
   packet.to.rpcid = rpcid
   packet.fromid = self.ownid

   --print("OUT!")
   --table.foreach(packet, print)
   local raw = encodepacket(packet)
   packet.raw = raw

   --print("the outgoing packet table")
   --table.foreach(packet, print)
   --print("to:")
   --table.foreach(packet.to, print)
   
   print("CALL: packet to " .. packet.to.addr .. ":" 
	 .. packet.to.port ..            -- 0xdeadbeef
	 ":" .. ec.tohex(packet.to.id or "\222\173\190\239")  
         .. " rpcid " ..	 ec.tohex(rpcid))
   

   self.running[rpcid] = {proc=proc, packet=packet}

   spacket(packet)
   srun(self.timeoutf, self, rpcid, timeout)
   self.livelinessmanager:outcomm(packet.to, rpcid)

end

function CallManager:outgoingloop()
   sregister("callmanager")
   while 1 do
      --print("CALLMANAGER OUTGOING WAITING FOR REQUEST")
      local from, req = swreq()
      --print("CALLMANAGER OUTGOING LOOP GOT REQUEST!")
      self:outgoing(from, req)
   end
end

