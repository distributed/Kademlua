


--timeout = 3600.314159
timeout = 3.1415
timeout = 4.1415
CallManager = {}




function CallManager:new(node)
   local o = {running = {},
	      scheduler = scheduler,
	      node = node,
	      ownid = node.id
	  }
   if o.ownid == nil then error("need an ID",2) end
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
      sresp(runningt.proc, {false})
      --table.insert(self.scheduler.readyq, {proc=runningt.proc, args={false}})
   else
      -- do nothing ...
   end
end


function CallManager:incomingloop()
   while 1 do
      packets = coroutine.yield("gp")
      for i, pack in ipairs(packets) do
	 decodepacket(pack)
      end
      print("INCOMING PACKETS")
      --table.foreach(packets, print)
      
      srun(self.incoming, self, packets)
      --self:incoming(packets)
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
		     sresp(callt.proc, {true})
		     --table.insert(self.scheduler.readyq, {proc=callt.proc, args={}})
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
		  outpacks = self.node:inping(packet)
	       end
	       for i, pack in ipairs(outpacks) do
		  spacket(pack)
		  --table.insert(self.scheduler.packetq, pack)
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

   spacket(packet)
   srun(self.timeoutf, self, rpcid, timeout)

end

function CallManager:outgoingloop()
   sregister("callmanager")
   while 1 do
      print("CALLMANAGER OUTGOING WAITING FOR REQUEST")
      from, req = swreq()
      print("CALLMANAGER OUTGOING LOOP GOT REQUEST!")
      self:outgoing(from, req)
   end
end

