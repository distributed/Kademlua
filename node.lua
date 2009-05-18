
-- node.lua
-- (C) 2009, Michael Meier

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

   --print("reply from callmanager")
   --table.foreach(rep,print)
   
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
   --table.foreach(retpacket, print)
   --print("ret")
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
   --table.foreach(rets, print)
   --print("----")
   return unpack(rets)
end

function KademluaNode:inping(from)

   --print("INPING")
   

   
   --local outpack = {call=129, 
--		    rpcid=packet.rpcid,
--		    fromid=self.id,
--		    to=packet.from}
   --local rraw = encodepacket(outpack)
   --outpack.raw = rraw
   --print("~~~~~~~~~ PONG!")
   
   return 5
end

--function KademluaNode:infindnode(id)
--   if type(id) ~= "string" then return 0 end
--   if #id ~= 20 then return 0 end
--
--   
--end


function KademluaNode:infindnode(from, id)
   --print("infindnode", id)
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
      --print("//// " .. addr)
      -- TODO: should check for a valid or a kind-of-valid IP
      if type(addr) == "string" then
        --print"addr"
        local port = n[2]
        if type(port) == "number" and port > 0 and port <= 0xffff then
           --print"port"
           local id = n[3]
           if type(id) == "string" and #id == 20 then
              --print("id")
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


function KademluaNode:iterativefindnode(id, bootstrap)
   print("NODE: iterativefindnode " .. ec.tohex(id))
   local inorder = bootstrap or self.routingtable:getclosest(id)
   local processed = {}
   local known = {}
   local myid = self.id
   for i,v in ipairs(inorder) do
      -- anti loopback
      if id ~= v.id then
	 v.distance = ec.xor(id, v.id)
	 known[v.unique] = v
      end
   end

   local alpha = 3

   local insert = table.insert
   local remove = table.remove
   local sort = table.sort
   local done = false
   local numrunning = alpha
   local order = function(a,b) 
		    if a == b then 
		       return false
		    end
		    -- kind of DoS protection
		    if a.distance == b.distance then return true end
		    --print(a, b)
		    --print(ec.tohex(a.distance), ec.tohex(b.distance))
		    --print(a.addr .. ":" .. a.port .. " / " .. b.addr .. ":" .. b.port)
		    return not RoutingTable.strcomp(a.distance, b.distance) 
		 end

   table.sort(inorder, order)

   callnr = 0

   retchannel = Channel:new()

   local function getretval()
      for i,v in pairs(processed) do
	 insert(inorder, v)
      end
      sort(inorder, order)
      local len = #inorder

      ret = {}
      for i=math.max(1,len-20+1),len do
	 insert(ret, inorder[i])
      end

      return ret
   end


   local function clerkreturn()
      print("CLERK: clerkreturn()")
      numrunning = numrunning - 1
      if numrunning > 0 then return end
      local retval = getretval()
      retchannel:send(retval)
      done = true
   end
   

   local function clerk()
      callnr = callnr + 1
      local mycallnr = callnr
      print("CLERK: waking up, callnr. " .. callnr .. " #inorder " .. #inorder)
      local contact = remove(inorder)
      if contact == nil then
	 clerkreturn()
	 return
      end
      
      print("CLERK: callnr " .. mycallnr .. " fetched dist " .. ec.tohex(contact.distance))

      processed[contact.unique] = contact
      if known[contact.unique] == nil then error("contact is not in known table, even though it should be") end
      local errorfree, closest = self:findnode(contact, id)
      
      -- proper tail calls FTW
      if not errorfree then clerk() end

      print("CLERK: min before: " .. ec.tohex(inorder[#inorder].distance))
      print("CLERK: #closest " .. #closest)
      local inserted = 0
      for i,v in ipairs(closest) do
	 if known[v.unique] == nil then
	    v.distance = ec.xor(id, v.id)
	    print("CLERK:       " .. ec.tohex(v.distance))
	    insert(inorder, v)
	    known[v.unique] = v
	    inserted = inserted + 1
	 end
      end

      if inserted == 0 then
	 clerkreturn()
	 return
      end

      sort(inorder, order)
      print("CLERK: min after:  " .. ec.tohex(inorder[#inorder].distance))

      local len = #inorder

      if len == 0 then 
	 clerkreturn() 
	 return
      end

      local lower = math.max(1,len-20+1)
      local newlen = len - lower + 1
      print("CLERK: lew, lower, newlen " .. len, lower, newlen, contact.addr .. ":" .. contact.port)
      local newinorder = {}
      for i=lower,len do
	 insert(newinorder, inorder[i])
      end


      --local oldmindist = inorder[len].distance
      local oldmindist = contact.distance
      local newmindist = inorder[len].distance
      print("CLERK: newmin, oldmin: " .. ec.tohex(newmindist) .. " .. " .. ec.tohex(oldmindist))
      if not RoutingTable.strcomp(newmindist, oldmindist) then
	 print("CLERK: it's not getting better...")
	 clerkreturn()
	 return
      end

      inorder = newinorder

      -- proper tail calls FTW!
      clerk()
   end

   
   for i=1,alpha do
      srun(clerk)
   end
   
   local retval = retchannel:receive()
   print("NODE: received on retchannel, len " .. #retval)
   for i,v in ipairs(retval) do
      print("NODE: " .. i .. ": " .. ec.tohex(v.distance))
      --table.foreach(v, print)
   end

   return retval
end


function KademluaNode:run()
   srun(self.callmanager.outgoingloop, self.callmanager)
   srun(self.callmanager.incomingloop, self.callmanager)
end