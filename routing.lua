

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


function RoutingTable:getpos(node)
   local bucketno = math.min(ec.getbucketno(node.distance), self.maxbucket)

   local bucket = self.buckets[bucketno]

   if bucket.byunique[node.unique] ~= nil then
      for i, nodei in ipairs(bucket.inorder) do
	 if node.unique == nodei.unique then
	    return bucketno, i
	 end
	 error("inconsistent routing table")
      end
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
      node = self:removenodeatpos(node, bucketno, i)
      self:insertnodeinbucket(node, bucketno)
   else
      -- insert a new node
      self:newnode(node)
   end
end



function RoutingTable:print()
   for i=1,self.maxbucket do
      local bucket = self.buckets[i]
      print("bucket " .. tostring(i) .. ":")
      for j,node in ipairs(bucket.inorder) do
	 print(ec.tohex(node.id) .. " | " .. ec.tohex(node.distance))
      end
   end
end



function RoutingTable:dryrun()
   --rtid = string.rep("\0", 20)
   --rt = RoutingTable:new(rtid)
   rt = RoutingTable:new("das esch de rap shit")
   
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
   
   --os.exit(0)
end