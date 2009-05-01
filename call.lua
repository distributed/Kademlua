


timeout = 3.1415
CallManager = {}




function CallManager:new(scheduler, ownid)
   o = {running = {},
	scheduler = scheduler,
	ownid = ownid
	  }
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
      --table.foreach(self.running, print)
      if self.running[rpcid] ~= nil then
	 callt = self.running[rpcid]
	 -- we initiated that call
	 print("incoming response, rpc id " .. rpcid)
	 self.running[rpcid] = nil
	 table.insert(self.scheduler.readyq, {proc=callt.proc, args={}})
      else
	 print("incoming call")
	 -- we did not
      end
   end
end


function CallManager:outgoing(proc, packet)
   
   local rpcid = string.sub(ec.sha1(tostring(math.random())), 1, 8)
   rpcid = "64bitqnt"
   
   packet.rpcid = rpcid
   packet.to.rpcid = rpcid

   local raw = encodepacket(packet)
   packet.raw = raw

   self.running[rpcid] = {proc=proc, packet=packet}

   table.insert(self.scheduler.packetq, packet)
   self.scheduler:runf(self.timeoutf, self, rpcid, timeout)

end