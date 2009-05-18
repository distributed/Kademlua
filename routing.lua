
-- routing.lua
-- (C) 2009, Michael Meier

RoutingTable = {}

function RoutingTable:new(id)
   local o = {id=id,
	      buckets={{byunique={}, inorder={}, count=0}},
	      nodes={},
	      maxbucket=1,
	      k=20
	   }
   
   setmetatable(o,self)
   self.__index = self
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
   node = table.remove(bucket.inorder, i)
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
	 local newbucket = {byunique={}, inorder={}, count=0}
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
	 print("PROBING LEAST RECENTLY SEEN NODE IN BUCKET " .. tostring(bucketno))
      end
   end
end


function RoutingTable:seenode(node)

   local unique = node.unique
   local nodeid = node.id
   
   -- loopback
   if nodeid == self.id then return end

   local distance = ec.xor(self.id, nodeid)

   -- copy node info
   node = {addr=node.addr, 
	   port=node.port, 
	   id=node.id,
	   unique=node.unique,
	   distance=distance}

   local bucketno, i = self:getpos(node)
   if bucketno then
      -- move to tail of LRS queue
      -- node = self:removenodeatpos(node, bucketno, i)
      node = self:removenodeatpos(bucketno, i)
      self:insertnodeinbucket(node, bucketno)
   else
      -- insert a new node
      self:newnode(node)
   end
   --self:print()
end


function RoutingTable:getclosest(id, n)
   local n = n or 20
   local distance = ec.xor(self.id, id)

   local bucketno = math.min(ec.getbucketno(distance), self.maxbucket)

   local ret = {}
   local basebucket = self.buckets[bucketno]
   local inorder = basebucket.inorder
   local bound = math.min(n, basebucket.count)
   for i=1,bound do table.insert(ret, inorder[i]) end
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
	 for i=1,bound do table.insert(ret, inorder[i]) end
	 retn = retn + bound
      end

      if retn == n then return ret end
      if cangodown then
	 local bucket = self.buckets[bucketno + i]
	 local inorder = bucket.inorder
	 local bound = math.min(bucket.count, n - retn)
	 for i=1,bound do table.insert(ret, inorder[i]) end
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
   rt = RoutingTable:new("das esch de rap shit")
   rt = RoutingTable:new(string.rep("\0", 20))
   
   myaddr = "192.168.1.5"
   
   math.randomseed(42)
   nodes = {}
   for i = 1,500 do
      table.insert(nodes,
		   {addr=myaddr, port=4200, id=ec.sha1(tostring(math.random()))})
   end
   
   for i, node in ipairs(nodes) do
      node.unique=node.addr .. ":" .. tostring(node.port) .. ":" .. node.id
      rt:seenode(node)
   end
   
   rt:print()

   local searchid = string.rep("\8",20)
   local t1 = ec.time()
   cl = rt:getclosest(searchid, 20)
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