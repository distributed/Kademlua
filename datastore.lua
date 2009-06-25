

-- datastore.lua
-- (C) 2009, Michael Meier

local bucketduration = 120
local maxage = 120

DataStore = {}

function DataStore:new(id)
   local o = {
      byhash = {},
      byowner = {},
      byownerandkey = {},
      timebuckets = {},
      stop = false
   }

   srun(DataStore.agecheck, o)

   setmetatable(o,self)
   self.__index = self
   return o
end


function DataStore.copyowner(owner)
   --local unique = owner.addr .. "|" .. tostring(owner.port) .. "|" .. owner.id
   return {id=owner.id,
	   addr=owner.addr,
	   port=owner.port,
	   unique=owner.unique}
end
   

function DataStore.ownerandkey(owner, key)
   return (owner.unique .. key)
end


function DataStore:agecheck()
   local time = ec.time
   local floor = math.floor
   local timebuckets = self.timebuckets
   local maxage = maxage

   while not self.stop do
      ssleep(bucketduration / 2)
      local now = time()
      local timebucketno = floor((now - maxage) / bucketduration)
      
      local timebucket = timebuckets[timebucketno]
      while timebucket do
	 -- build a list of entries to remove so as not to interfere
	 -- with removeentry
	 local toremove = {}
	 for k, v in pairs(timebucket) do toremove[k] = v end
	 
	 -- and remove them
	 for k, v in pairs(toremove) do
	    self:removeentry(v)
	 end

	 timebucketno = timebucketno - bucketduration
	 timebucket = timebuckets[timebucketno]
      end
   end
end


function DataStore:removeentry(entry)
   self.byhash[entry.key][entry] = nil
   self.byowner[entry.owner.unique][entry] = nil
   self.timebuckets[entry.timebucketno][entry] = nil
   self.byownerandkey[entry.ownerandkey] = nil
end


-- insert a new entry (owner, key, value) if it *does not exist* yet.
function DataStore:addentry(owner, key, value)
   local now = ec.time()

   local unique = owner.unique
   if not unique then
      unique = owner.addr .. "|" .. tostring(owner.port) .. "|" .. owner.id
      owner.unique = unique
   end

   local owner = DataStore.copyowner(owner)
   local timebucketno = math.floor(now / bucketduration)
   local ownerandkey = DataStore.ownerandkey(owner, key)

   local entry = {key=key,
		  value=value,
		  owner=owner,
		  timebucketno=timebucketno,
		  ownerandkey=ownerandkey
	       }

   local hashentries = self.byhash[key]
   if hashentries then
      hashentries[entry] = entry
   else
      self.byhash[key] = {[entry] = entry}
   end

   local ownerentries = self.byowner[unique]
   if ownerentries then
      ownerentries[entry] = entry
   else
      self.byowner[unique] = {[entry] = entry}
   end
   
   local timebucket = self.timebuckets[timebucketno]
   if timebucket then
      timebucket[entry] = entry
   else
      self.timebuckets[timebucketno] = {[entry] = entry}
   end

   self.byownerandkey[ownerandkey] = entry

   --local 
   
   return entry
end


function DataStore:updateentry(entry, value)
   entry.value = value

   local now = ec.time()

   local oldtimebucketno = entry.timebucketno
   local newtimebucketno = math.floor(now / bucketduration)
   if newtimebucketno ~= oldtimebucketno then
      self.timebuckets[oldtimebucketno][entry] = nil

      local timebucketno = newtimebucketno
      entry.timebucketno = timebucketno
      
      local timebucket = self.timebuckets[timebucketno]
      if timebucket then
	 timebucket[entry] = entry
      else
	 self.timebuckets[timebucketno] = {[entry] = entry}
      end
   end

end


function DataStore:getvaluesbykey(key)
   local hashentries = self.byhash[key]
   local insert = table.insert
   if hashentries then
      local ret = {}
      for k, v in pairs(hashentries) do insert(ret, v.value) end
      return ret
   else
      return nil
   end
   
end


function DataStore:getbyownerandkey(owner, key)
   local ownerandkey = DataStore.ownerandkey(owner, key)
   
   return self.byownerandkey[ownerandkey]
end


function DataStore:overwrite(owner, key, value)
   local byhash = self.byhash[key]

   -- if there already are entries for this key then remove them
   if byhash then
      -- shallow copy self.byhash[key] so as not to interfere with
      -- removeentry
      local entries = {}
      for k, v in pairs(byhash) do entries[k] = v end
      
      for n, entry in pairs(byhash) do
	 self:removeentry(entry)
      end
   end

   self:add(owner, key, value)
end


function DataStore:add(owner, key, value)
   local entry = self:getbyownerandkey(owner, key)
   if entry then
      self:updateentry(entry, value)
   else
      self:addentry(owner, key, value)
   end
end
