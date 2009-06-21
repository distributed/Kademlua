
-- node.lua
-- (C) 2009, Michael Meier

KademluaNode = {}

function KademluaNode:new(id)
   local id = id or ec.sha1(tostring(math.random()))
   local o = {id = id,
	      rpcdispatch = {["ping"] = self.inping,
			     ["findnode"] = self.infindnode,
			     ["store"] = self.instore,
			     ["findvalue"] = self.infindvalue
			    },
	      datastore = DataStore:new()
	   }

   o.routingtable = RoutingTable:new(id, o)
   o.callmanager = CallManager:new(o)

   setmetatable(o,self)
   self.__index = self
   return o
end

function KademluaNode:sendRPC(whom, name, ...)

   if type(name) ~= "string" then error("name needs to be a string", 2) end


   local arg = arg
   arg.n = nil

   --print("SENDRPC: name ", name, " arg: ", unpack(arg))
   --for name, val in pairs(arg) do print("SENDRPC:", name, val) end


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
   
   return rep.reply, rep.from, unpack(rep.payload)
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
   local rets = {self:sendRPC(who, "ping")}
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

function KademluaNode:attachfindnode(from, id, ret)
   local insert = table.insert
   local entries = self.routingtable:getclosest(id)
   local fromid = from.id
   for i, v in ipairs(entries) do
      if v.id ~= fromid then insert(ret, {v.addr, v.port, v.id}) end
   end
   
   return ret
end


function KademluaNode:infindnode(from, id)
   --print("infindnode", id)
   if type(id) ~= "string" then return 0 end
   if #id ~= 20 then return 0 end

   local ret = {}
   return self:attachfindnode(from, id, ret)
end


function KademluaNode:filternodelist(nodelist)
   local retnodelist = {}
   local insert = table.insert
   
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
	       local unique = addr .. "|" .. port .. "|" .. id
	       local node = {addr=addr,
			     port=port,
			     id=id,
			     unique=unique
			  }
	       print(addr .. "|" .. port .. "|" .. ec.tohex(id))
	       --self.routingtable:seenode(node)
	       insert(retnodelist, node)
	    end
	 end
      end
   end

   return retnodelist
end

function KademluaNode:findnode(who, id)

   local errorfree, from, nodelist = self:sendRPC(who, "findnode", id)
   print("FINDNODE " .. who.addr .. ":" .. who.port .. "  =>  " .. tostring(errorfree))

   if not errorfree then return false, from end

   local retnodelist = self:filternodelist(nodelist)

   print()
   print()
   --self.routingtable:print()
   print()

   return true, from, retnodelist
end


function KademluaNode:instore(from, id, data, add)
   if type(id) ~= "string" then return 0 end
   if #id ~= 20 then return 0 end

   if add == 1 then
      self.datastore:overwrite(from, id, data)
   else
      self.datastore:add(from, id, data)
   end

   return 1
end


function KademluaNode:store(where, id, what)
   return self:sendRPC(where, "store", id, what)
end


function KademluaNode:iterativestore(id, what)
   local nodelist = self:iterativefindnode(id)
   for i, node in ipairs(nodelist) do
      local errorfree, ret = self:store(node, id, what)
      print("STORE: on " .. node.addr .. ":" .. node.port .. " => " .. tostring(errorfree))
   end
end


function KademluaNode:iterativeadd(id, what)
   local nodelist = self:iterativefindnode(id)
   for i, node in ipairs(nodelist) do
      local errorfree, ret = self:store(node, id, what, 1)
      print("ADD: on " .. node.addr .. ":" .. node.port .. " => " .. tostring(errorfree))
   end
end


function KademluaNode:infindvalue(from, id, howmany)
   print("INFINDVALUE: in")
   if type(id) ~= "string" then return {} end
   if #id ~= 20 then return {} end
   print("INFINDVALUE: not rejected")

   local howmany = howmany or 1
   print("INFINDVALUE: howmany: " .. tostring(howmany))

   local ret = {}
   --local val = self.datastore[id]
   local values = self.datastore:getvaluesbykey(id)
   -- if the nothing has been found for the specified id: return
   -- nothing
   if values then
      local valueslen = #values
      if valueslen <= howmany then
	 ret.retval = values
      else
	 local shorter = {}
	 for i=1,howmany do shorter[i] = values[i] end
	 ret.retval = shorter
      end
   end
   

   -- TODO: think about how many closest nodes to return. there should
   -- probably be a distinction between the case when we know some
   -- entries and the case when we do not.
   ret.closest = {}
   local fromid = from.id
   local strcomp = RoutingTable.strcomp
   local insert = table.insert
   local ownid = self.id
   local dist = ec.xor(id, ownid)
   for i, node in ipairs(self.routingtable:getclosest(id)) do
      -- if we know nodes closer to the key than we are, return them also
      if strcomp(ec.xor(node.id, ownid), dist) then
	 insert(ret.closest, {node.addr, node.port, node.id})
      end
   end

   return ret
end


function KademluaNode:findvalue(who, id, howmany)
   return self:sendRPC(who, "findvalue", id, howmany)
end


function KademluaNode:iterativefindvalue(id, max, maxentries)
   -- maximum number of answering nodes to consider
   local max = max or 3
   -- maximum number of entries to return
   print("maxentries:",maxentries)
   local maxentries = maxentries or 4096
   local extra = {max=max, args={maxentries}}
   return self:iterativefind(id, "findvalue", extra)
end


function KademluaNode:bootstrap(bootstrap)
   -- ask the bootstrap nodes for nodes close to us
   local byunique = {}
   local findnodebootstrap = {}
   for i, contact in ipairs(bootstrap) do
      local errorfree, from, nodelist = self:findnode(contact, self.id)
      if errorfree then
	 for i,v in ipairs(nodelist) do 
	    -- maintain set property of findnodebootstrap
	    if byunique[v.unique] == nil then
	       table.insert(findnodebootstrap, v) 
	       byunique[v.unique] = v
	    end
	 end
      else
	 print("BOOTSTRAP: ERROR on outer nodelist: " .. contact.addr .. ":" .. contact.port)
      end
   end



   -- ping all closest nodes not previously contacted
   local neighbours, processed = self:iterativefindnode(self.id, findnodebootstrap)
   for i,neigh in ipairs(neighbours) do
      if processed[neigh.unique] == nil then
	 self:ping(neigh)
      end
   end

   --balance the routing a table a little bit by looking for ids far away
   local onemask = string.rep("\255", 20)
   local oppositeid = ec.xor(onemask, self.id)
   local faraway, processed = self:iterativefindnode(oppositeid)
   for i=1,math.min(#faraway,5) do
      local mom = faraway[i]
      if not processed[mom.unique] then
	 self:ping(mom)
      end
   end
   
end


function KademluaNode:iterativefindnode(id, bootstrap)
   return self:iterativefind(id, "findnode", {numret=65535}, bootstrap)
end


function KademluaNode:iterativefind(id, rpc, extra, bootstrap)
   print("NODE: iterativefind " .. ec.tohex(id))

   local rpc = rpc or "findnode"
   local numret = 3
   local args = {}
   if extra and type(extra) == "table" then
      numret = extra.numret or numret
      args = extra.args or args
   end

   local findnode = (rpc == "findnode")

   local inorder = bootstrap or self.routingtable:getclosest(id)


   local processed = {}
   local known = {}
   local retsgot = 0
   local rets = {n=0}
   local myid = self.id
   for i,v in ipairs(inorder) do
      -- here is a TODO: 
      -- "anti loopback" 
      
      -- this does not make any sense, this excludes some nodes from
      -- the known table while they still are in the inorder table and
      -- don't have a real distance metric. huh.
      --if id ~= v.id then
	 v.distance = ec.xor(id, v.id)
	 known[v.unique] = v
      --end
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

   local callnr = 0
 
   local retchannel = Channel:new()

   local function getretval()
      for i,v in pairs(processed) do
	 insert(inorder, v)
      end
      sort(inorder, order)
      local len = #inorder

      local ret = {}
      for i=math.max(1,len-20+1),len do
	 insert(ret, inorder[i])
      end

      return ret
   end


   local function clerkreturn()
      print("CLERK: clerkreturn()")
      numrunning = numrunning - 1
      if numrunning > 0 then return end

      if findnode then
	 local retval = getretval()
	 retchannel:send(retval)
      else
	 retchannel:send(rets)
      end

      done = true
   end
   

   local function clerk()
      callnr = callnr + 1
      local mycallnr = callnr
      print("CLERK: waking up, callnr. " .. callnr .. " #inorder " .. #inorder)

      -- we already have enough answers
      if not findnode and rets.n >= numret then
	 clerkreturn()
	 return
      end

      local contact = remove(inorder)
      if contact == nil then
	 clerkreturn()
	 return
      end
      
      print("CLERK: callnr " .. mycallnr .. " fetched dist " .. ec.tohex(contact.distance))

      processed[contact.unique] = contact
      if known[contact.unique] == nil then error("contact is not in known table, even though it should be") end
      --local errorfree, closest = self:findnode(contact, id)

      local errorfree, from, closest = self[rpc](self, contact, id, unpack(args))
      print("CLERK: RPC " .. rpc .. " => " .. tostring(errorfree))
      -- proper tail calls FTW
      if not errorfree then return clerk() end
      if type(closest) ~= "table" then 
	 print("CLERK: did not get a table")
	 return clerk()
      end

      -- are we looking for a return value and is the respondent not just
      -- returning a list of nodes?
      if not findnode then
	 print("CLERK: not findnode")
	 if closest.retval then 
	    local retval = closest.retval
	    print("CLERK: got retval: " .. tostring(retval))
	    
	    -- TODO: stronger checks about correctness of retval
	    if rets.n < numret then
	       rets[from.unique] = {retval=retval, from=from}
	       rets.n = rets.n + 1
	       if rets.n == numret then
		  clerkreturn()
		  return
	       end
	    end
	 end

	 -- as it may be nested
	 if type(closest) ~= "table" then return clerk() end
	 closest = self:filternodelist(closest.closest)
	 --return clerk()
      end

      pcall(function() 
	       print("CLERK: min before: " .. ec.tohex(inorder[#inorder].distance)) 
	 end)
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
	 -- TODO: this is probably a bit too much GDR style for
	 -- findvalue: "Vorwärts immer, rückwärts nimmer!". if
	 -- findvalue starts with nodes very close to the "target" and
	 -- these nodes do not have the requested value, nothing is
	 -- returned. there has to be a strategy if a value is missing
	 -- in the closest nodes, either here or with a more
	 -- persistent iterativefindvalue implementation which may use
	 -- the original iterativefindvalue and the inorder dict
	 -- returned by it.
	 print("CLERK: it's not getting better...")
	 clerkreturn()
	 return
      end

      inorder = newinorder

      -- proper tail calls FTW!
      return clerk()
   end

   
   for i=1,alpha do
      srun(clerk)
   end
   
   local retval = retchannel:receive()
   print("NODE: received on retchannel, len " .. #retval)
   for i,v in ipairs(retval) do
      if findnode then
	 print("NODE: " .. i .. ": " .. ec.tohex(v.distance))
      else
	 print("NODE: " .. i .. " returned " .. tostring(v))
      end
      --table.foreach(v, print)
   end

   return retval, processed, inorder
end


function KademluaNode:run()
   srun(self.callmanager.outgoingloop, self.callmanager)
   srun(self.callmanager.incomingloop, self.callmanager)
end