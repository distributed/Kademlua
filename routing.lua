
-- routing.lua
-- (C) 2009, Michael Meier

-- maximum length of eventpipe (when written to by seenode)
local maxeventpipelen = 100
-- how soon a bucketwatchdog starts a probe again
local probebackoff = 5.0 

-- maximum age of entries in routing table to go unchecked if bucket
-- is full
local maxage = 120


RoutingTable = {k=20}

function RoutingTable:new(id, node)
   local o = {id=id,
	      node=node,
	      nodes={},
	      maxbucket=1
	   }

   setmetatable(o,self)
   self.__index = self

   o.buckets= {o:newbucket()}

   if o.node == nil then error("RoutingTable needs a node") end

   return o
end


function RoutingTable.strcomp(a, b)
   --print("COMP: in")
   if #a ~= #b then error("strings have to be of the same length", 2) end
   local i = 1
   local len = #a
   while i <= len do
      --print("COMP: " .. ec.tohex(string.sub(a,i,i)) .. " <? " .. ec.tohex(string.sub(b,i,i)))
      local ba = string.byte(a, i)
      local bb = string.byte(b, i)
      --print("COMP: ", ba, bb)
      if ba < bb then return true end
      if ba > bb then return false end
      i = i + 1
   end
   return false
end


function RoutingTable:newbucket()

   local eventpipe = Channel:new()
   local bucket = {byunique={}, 
		   inorder={}, 
		   count=0,
		   eventpipe=eventpipe,
		   nodequeue={}
		  }

   srun(RoutingTable.bucketwatchdog, self, bucket, eventpipe)

   return bucket
end


function RoutingTable.copynode(node)
   return {addr=node.addr,
	   port=node.port,
	   id=node.id,
	   unique=node.unique,
	   distance=node.distance
	  }
end


function RoutingTable:bucketwatchdog(bucket, eventpipe)
   
   local nodequeue = bucket.nodequeue
   local k = RoutingTable.k
   
   local maxage = maxage or 10

   local lastprobetime = 0

   while true do
      local cmd, node = eventpipe:receive()

      print("ROUTING: bucketwatchdog: " .. cmd)

      if cmd == "free" then
	 print("ROUTING: bucketwatchdog: bucket.count", bucket.count)
      end

      if cmd == "new" or cmd == "free" then
	 -- get some node
	 local func, tab, par = pairs(nodequeue)
	 local unique, node = func(tab, par)


	 if node then
	    -- delete the node from the table
	    nodequeue[unique] = nil
	    
	    -- if we have some node to insert
	    if bucket.count < k then
	       print("ROUTING: bucketwatchdog: fits in: " .. node.addr .. "|" .. tostring(node.port))
	       -- and there is free space in the bucket
	       local bucketno = self:getpos(node)
	       if not bucketno then
		  -- and the node does not yet exist in the routing
		  -- table... insert it
		  self:newnode(node)
		  nodequeue[node.unique] = nil
	       end

	    else
	       -- and there is no free space in the routing table
	       local livelinessmanager = self.node.callmanager.livelinessmanager

	       local now = ec.time()
	       
	       -- get the least recently seen node
	       local lrsnode = bucket.inorder[1]
	       -- check if it has been active in the last maxage
	       -- seconds
	       if (now - lastprobetime) > probebackoff and 
	          not livelinessmanager:isweaklyalive(lrsnode, maxage) then
		  
		  -- if not: check if it responds
		  livelinessmanager:isstronglyalive(lrsnode)
		  lastprobetime = now
		  -- when the node is not alive we will be called back
		  -- via our eventpipe
		  
		  -- at the moment incoming "new" nodes are not
		  -- cached, thus i reinsert the new node after the
		  -- "free" message of the livelinessmanager
		  nodequeue[node.unique] = node
		  scall(function()
			   eventpipe:sendasync("new", node)
			end)
	       end
	    end
	 end
      end
   end

end


function RoutingTable:getpos(node)
   local bucketno = math.min(ec.getbucketno(node.distance), self.maxbucket)

   local bucket = self.buckets[bucketno]

   if bucket.byunique[node.unique] ~= nil then
      for i, nodei in ipairs(bucket.inorder) do
	 if node.unique == nodei.unique then
	    return bucketno, i
	 end
      end
      error("inconsistent routing table")
   else
      return false
   end
end


function RoutingTable:removenodeatpos(bucketno, i)
   local bucket = self.buckets[bucketno]
   local node = table.remove(bucket.inorder, i)
   bucket.byunique[node.unique] = nil
   bucket.count = bucket.count - 1
   return node
end


function RoutingTable:insertnodeinbucket(node, bucketno)
   local bucket = self.buckets[bucketno]
   bucket.byunique[node.unique] = node
   table.insert(bucket.inorder, node)
   bucket.count = bucket.count + 1
end


function RoutingTable:newnode(node)
   local bucketno = math.min(ec.getbucketno(node.distance), self.maxbucket)
   local bucket = self.buckets[bucketno]

   if bucket.count < self.k then
      self:insertnodeinbucket(node, bucketno)
   else
      if bucketno == self.maxbucket then
	 -- split the bucket
	 self.maxbucket = self.maxbucket + 1
	 local oldbucket = self.buckets[self.maxbucket - 1]
	 local newbucket = self:newbucket()
	 self.buckets[self.maxbucket] = newbucket
	 
	 local nodecache={}
	 for i, nodei in ipairs(oldbucket.inorder) do table.insert(nodecache,nodei) end
	 oldbucket.inorder = {}
	 oldbucket.byunique = {}
	 oldbucket.count = 0

	 for i, nodei in ipairs(nodecache) do
	    self:newnode(nodei)
	 end
	 self:newnode(node)
      else
	 -- maybe replace an old node
	 --print("PROBING LEAST RECENTLY SEEN NODE IN BUCKET " .. tostring(bucketno))
	 print("ROUTING: new? bucketno " .. bucketno .. " on pipe " .. tostring(bucket.eventpipe))
	 local eventpipe = bucket.eventpipe
	 if eventpipe.balance < maxeventpipelen then
	    print("ROUTING: new to watchdog for " .. node.addr .. "|" .. tostring(node.port))
	    bucket.nodequeue[node.unique] = node
	    eventpipe:sendasync("new", node)
	 end
      end
   end
end


function RoutingTable:nodedown(node)
   local node = RoutingTable.copynode(node)


   if not node.id then 
      -- contact is not complete so we don't know what to remove
      return
   end

   print("XOR")
   local distance = ec.xor(self.id, node.id)
   print("done")
   node.distance = distance

   local bucketno, i = self:getpos(node)
   if bucketno then
      -- if the node exists in our table, remove it
      self:removenodeatpos(bucketno, i)
      -- notify the watchdog
      self.buckets[bucketno].eventpipe:sendasync("free")
   end
end


function RoutingTable:seenode(node)

   local unique = node.unique
   local nodeid = node.id
   
   -- loopback
   if nodeid == self.id then return end

   local distance = ec.xor(self.id, nodeid)

   -- copy node info
   local node = {addr=node.addr, 
	   port=node.port, 
	   id=node.id,
	   unique=node.unique,
	   distance=distance}

   local bucketno, i = self:getpos(node)
   if bucketno then
      -- move to tail of LRS queue
      -- node = self:removenodeatpos(node, bucketno, i)
      local node = self:removenodeatpos(bucketno, i)
      self:insertnodeinbucket(node, bucketno)
   else
      -- insert a new node
      self:newnode(node)
   end
   --self:print()
end


function RoutingTable:getclosest(id, n)
   -- this function does not return contacts directly, but instead
   -- shallow copies them so as to prevent accidentally tampering with
   -- them by, say, changing the distance

   local n = n or 20
   local distance = ec.xor(self.id, id)

   local bucketno = math.min(ec.getbucketno(distance), self.maxbucket)

   local copynode = RoutingTable.copynode

   local ret = {}
   local basebucket = self.buckets[bucketno]
   local inorder = basebucket.inorder
   local bound = math.min(n, basebucket.count)
   for i=1,bound do table.insert(ret, copynode(inorder[i])) end
   local retn = bound
   local i = 1

   --table.foreach(ret,print)

   local cangoup = (bucketno - i) >= 1
   local cangodown = (bucketno + i) <= self.maxbucket
   while (cangoup or cangodown) do
      cangoup = (bucketno - i) >= 1
      cangodown = (bucketno + i) <= self.maxbucket

      if retn == n then return ret end
      if cangoup then
	 local bucket = self.buckets[bucketno - i]
	 local inorder = bucket.inorder
	 local bound = math.min(bucket.count, n - retn)
	 for i=1,bound do table.insert(ret, copynode(inorder[i])) end
	 retn = retn + bound
      end

      if retn == n then return ret end
      if cangodown then
	 local bucket = self.buckets[bucketno + i]
	 local inorder = bucket.inorder
	 local bound = math.min(bucket.count, n - retn)
	 for i=1,bound do table.insert(ret, copynode(inorder[i])) end
	 retn = retn + bound
      end
      
      i = i + 1
   end
   
   return ret
end


function RoutingTable:print()
   for i=1,self.maxbucket do
      local bucket = self.buckets[i]
      print("bucket " .. tostring(i) .. ":")
      for j,node in ipairs(bucket.inorder) do
	 print(ec.tohex(node.id) .. 
	    " | " .. 
	    string.sub(ec.tohex(node.distance), 1, 10) ..
	    " @ " ..
	    node.addr ..
	    ":" ..
	    node.port)
      end
   end
end



function RoutingTable:dryrun()
   --rtid = string.rep("\0", 20)
   --rt = RoutingTable:new(rtid)
   local rt = RoutingTable:new("das esch de rap shit")
   local rt = RoutingTable:new(string.rep("\0", 20))
   
   local myaddr = "192.168.1.5"
   
   math.randomseed(42)
   local nodes = {}
   for i = 1,500 do
      table.insert(nodes,
		   {addr=myaddr, port=4200, id=ec.sha1(tostring(math.random()))})
   end
   
   for i, node in ipairs(nodes) do
      node.unique=node.addr .. "|" .. tostring(node.port) .. "|" .. node.id
      rt:seenode(node)
   end
   
   rt:print()

   local searchid = string.rep("\8",20)
   local t1 = ec.time()
   local cl = rt:getclosest(searchid, 20)
   local t2 = ec.time()
   print("took: " .. ((t2 - t1)*1000))
   for i=1,#cl do
      print(i .. " => " .. ec.tohex(cl[i].id))
   end
   print("---")
   
   os.exit(0)
end


--rt = RoutingTable:new(string.rep("\0", 20))
--rt:dryrun()