


--timeout = 3600.314159
timeout = 3.1415
timeout = 4.1415
CallManager = {}




function CallManager:new(scheduler, node)
   local o = {running = {},
	      scheduler = scheduler,
	      node = node,
	      ownid = node.id
	  }
   if node == nil then error("need a node",2) end
   setmetatable(o,self)
   self.__index = self
   return o
end


function CallManager:timeoutf(rpcid, howsoon) 
   ssleep(howsoon)
   if self.running[rpcid] ~= nil then
      -- call timed out
      print("CALL TIMED OUT")
      runningt = self.running[rpcid]
      self.running[rpcid] = nil
      table.insert(self.scheduler.readyq, {proc=runningt.proc, args={false}})
   else
      -- do nothing ...
   end
end



function CallManager:incoming(packets)
   for i, packet in ipairs(packets) do
      --table.foreach(packet, print)
      local rpcid = packet.rpcid
      local from = packet.from
      table.foreach(packet, print)
      if packet.from ~= nil then
	 print("from")
	 table.foreach(packet.from,print)
      end
      -- prevent loopback
      if rpcid ~= self.ownid then
	 --table.foreach(self.running, print)
	 if self.running[rpcid] ~= nil then
	    local callt = self.running[rpcid]

	    if packet.call == callt.packet.call + 128 then
	       local to = callt.packet.to
	       if (to.addr == from.addr) and (to.port == from.port) then
		  if (to.id == nil) or (from.id == to.id) then
		     -- we initiated that call
		     print("incoming response, rpc id " .. rpcid)
		     self.running[rpcid] = nil
		     table.insert(self.scheduler.readyq, {proc=callt.proc, args={}})
		  else
		     print ("callers ID does not match")
		  end
	       else
		  print("IP/port does not match")
		  print("from:")
		  table.foreach(from, print)
		  print("to:")
		  table.foreach(to, print)
	       end
	    else
	       print("incoming call does not match outgoing call")
	    end
	 else
	    if packet.call < 128 then
	       print("incoming call")
	       if packet.call == 1 then
		  outpacks = node:inping(packet)
	       end
	       for i, pack in ipairs(outpacks) do
		  table.insert(self.scheduler.packetq, pack)
	       end
	    else
	       print("incoming call's rpcid does not match")
	    end
	    -- we did not
	 end
      end
   end
end


function CallManager:outgoing(proc, packet)
   
   local rpcid = string.sub(ec.tohex(ec.sha1(tostring(math.random()))), 1, 8)
   --rpcid = "64bitqnt"
   
   packet.rpcid = rpcid
   packet.to.rpcid = rpcid
   packet.fromid = self.ownid

   print("OUT!")
   table.foreach(packet, print)
   local raw = encodepacket(packet)
   packet.raw = raw

   print("the outgoing packet table")
   table.foreach(packet, print)
   print("to:")
   table.foreach(packet.to, print)
   
   self.running[rpcid] = {proc=proc, packet=packet}

   table.insert(self.scheduler.packetq, packet)
   self.scheduler:runf(self.timeoutf, self, rpcid, timeout)

end