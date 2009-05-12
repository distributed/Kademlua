

KademluaNode = {}

function KademluaNode:new(id)
   local id = id or ec.sha1(tostring(math.random()))
   local o = {id = id,
	      routingtable = RoutingTable:new(id),
	      rpcdispatch = {["ping"] = self.inping,
			     ["findnode"] = self.infindnode
			  }
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

   --print("incoming args for " .. payload.name .. "  =========>")
   --table.foreach(payload.args, print)
   --print("<======================")

   local func = self.rpcdispatch[payload.name]
   -- unknown RPC, TODO: handle this in a better way
   if func == nil then return {} end
   local ret = {func(self, packet.from, unpack(payload.args))}
   
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
   return unpack(rets)
end

function KademluaNode:inping(from)

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

--function KademluaNode:infindnode(id)
--   if type(id) ~= "string" then return 0 end
--   if #id ~= 20 then return 0 end
--
--   
--end


function KademluaNode:infindnode(from, id)
   print("infnindnode", id)
   if type(id) ~= "string" then return 0 end
   if #id ~= 20 then return 0 end

   local ret = {}
   local insert = table.insert
   local entries = self.routingtable:getclosest(id)
   local fromid = from.id
   for i, v in ipairs(entries) do
      if v.id ~= fromid then insert(ret, {v.addr, v.port, v.id}) end
   end
   
   return ret
end

function KademluaNode:findnode(who, id)

   local errorfree, nodelist = self:sendRPC(who, "findnode", id)
   print("FINDNODE " .. who.addr .. ":" .. who.port .. "  =>  " .. tostring(errorfree))

   if not errorfree then return false end

   retnodelist = {}
   for i, n in ipairs(nodelist) do
      local addr = n[1]
      print("//// " .. addr)
      -- TODO: should check for a valid or a kind-of-valid IP
      if type(addr) == "string" then
        print"addr"
        local port = n[2]
        if type(port) == "number" and port > 0 and port <= 0xffff then
           print"port"
           local id = n[3]
           if type(id) == "string" and #id == 20 then
              print("id")
              local unique = addr .. ":" .. port .. ":" .. id
              local node = {addr=addr,
                            port=port,
                            id=id,
                            unique=unique
                         }
              print(addr .. ":" .. port .. ":" .. ec.tohex(id))
              --self.routingtable:seenode(node)
	      table.insert(retnodelist, node)
           end
        end
      end
   end
   print()
   print()
   --self.routingtable:print()
   print()

   return true, retnodelist
end


function KademluaNode:bootstrap(bootstrap)
   local byunique = {}
   for i, contact in ipairs(bootstrap) do
      local errorfree, nodelist = self:findnode(contact, self.id)
      if errorfree then
	 for j, node in ipairs(nodelist) do
	    print("BOOTSTRAP: pinging " .. node.addr .. ":" .. node.port)
	    local errorfree, ret = self:ping(node)
	    print("BOOTSTRAP: ping res:", errorfree)
	 end
      else
	 print("BOOTSTRAP: ERROR on outer nodelist: " .. contact.addr .. ":" .. contact.port)
      end
   end
end


function KademluaNode:run()
   srun(self.callmanager.outgoingloop, self.callmanager)
   srun(self.callmanager.incomingloop, self.callmanager)
end