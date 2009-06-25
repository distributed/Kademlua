
local print = print

KademluaShell = {}

function KademluaShell:prettyprint(what, level)
   local level = level or 0

   local spacing = "    "

   if type(what) == "number" then
      print(spacing:rep(level) .. tostring(what))
   elseif type(what) == "string" then
      print(spacing:rep(level) .. ("%q"):format(what))
   elseif type(what) == "table" then
      for name, value in pairs(what) do
	 print(spacing:rep(level) .. tostring(name) .. " =>")
	 self:prettyprint(value, level + 1)
      end
   else
      print(spacing:rep(level) .. tostring(what))
   end
      
end

function KademluaShell:new(node)
   local o = {node=node
	     }

   setmetatable(o,self)
   self.__index = self
   return o
end


function KademluaShell:help(argtable)
   -- first argument is just this function, kinda unix argv style.
   local calledf, arg1, arg2 = unpack(argtable)

   print("dont PANIC!!!")
end


function KademluaShell:findnode(id)
   if (type(id) ~= "string")then
      return print("! need an id: expected string: findnode <id>")
   end

   local id = id

   if #id == 40 then
      local errorfree, convid = pcall(ec.fromhex, id)
      if not errorfree then 
	 print("! need an id: could not convert from hex: findnode <id>") 
	 return
      end
      id = convid
   elseif #id == 20 then
      -- fine
   else
      print("! need an id: incorrect length: findnode <id>")
      return
   end

   local nodelist, processed, inorder = self.node:iterativefindnode(id)
   for k, node in pairs(nodelist) do
      print(node.addr, node.port, ec.tohex(node.id), ec.tohex(ec.xor(node.id, id)))
   end
   print("while looking for", ec.tohex(id))
end


function KademluaShell:gc(cmd)
   local cmd = cmd or ""

   print(cmd)

   if cmd == "" then
      local memusage = collectgarbage("count")
      print(("lua memory usage: %1.3f kbytes"):format(memusage))
   elseif cmd == "collect" then
      local memusage = collectgarbage("count")
      print(("lua memory usage before: %1.3f kbytes"):format(memusage))

      collectgarbage("collect")

      local memusage = collectgarbage("count")
      print(("lua memory usage after: %1.3f kbytes"):format(memusage))

   elseif cmd == "step" then
      local memusage = collectgarbage("count")
      print(("lua memory usage before: %1.3f kbytes"):format(memusage))

      collectgarbage("step")

      local memusage = collectgarbage("count")
      print(("lua memory usage after: %1.3f kbytes"):format(memusage))
   end
end


function KademluaShell:routing(argtable)
   self.node.routingtable:print()
end


function KademluaShell:add(id, what)

   local id = id

   if (type(id) ~= "string")then
      return print("! need an id: expected string: add <id> <what>")
   end

   if #id == 40 then
      local errorfree, convid = pcall(ec.fromhex, id)
      if not errorfree then 
	 print("! need an id: could not convert from hex: add <id> <what>") 
	 return
      end
      id = convid
   elseif #id == 20 then
      -- fine
   else
      print("! need an id: incorrect length: findnode <id> <what>")
      return
   end

   self.node:iterativeadd(id, what)

end


function KademluaShell:findvalue(id, maxnodes, maxentriespernode)

   local id = id

   if (type(id) ~= "string")then
      return print("! need an id: expected string: findvalue <id> (maxnodes) (maxentriespernode)")
   end

   if #id == 40 then
      local errorfree, convid = pcall(ec.fromhex, id)
      if not errorfree then 
	 print("! need an id: could not convert from hex: findvalue <id> (maxnodes) (maxentriespernode)")
	 return
      end
      id = convid
   elseif #id == 20 then
      -- fine
   else
      print("! need an id: incorrect length: findvalue <id> (maxnodes) (maxentriespernode)")
      return
   end

   local maxnodes = maxnodes or 3
   if type(maxnodes) ~= "number" or maxnodes <= 0 then
      print("maxnodes needs to be a valid number")
      return
   end

   local maxentriespernode = maxentriespernode or 6
   if type(maxentriespernode) ~= "number" or maxentriespernode <= 0 then
      print("maxentriespernode needs to be a valid number")
      return
   end

   local startt = ec.time()
   local ret = self.node:iterativefindvalue(id, maxnodes, maxentriespernode)
   local endt = ec.time()
   ret.n = nil

   for i, what in pairs(ret) do
      if type(what) == "table" then
   	 print(what.from.addr .. ":" .. what.from.port .. ": " .. tostring(what.retval))
       local retval = what.retval
   	 if type(retval) == "table" then
	    self:prettyprint(retval)
   	 end
      else
	 print(what.from.addr .. ":" .. what.from.port .. ": " .. tostring(what))
      end
   end

   print(("in %4.2f ms"):format((endt - startt) * 1000))


   return ret
end


function KademluaShell:main()
   local errorfree, errmsg = sregisterforevent("stdin")
   print("KademluaShell: register:", errorfree, errmsg)
   if not errorfree then
      error("KademluaShell could not register for stdin event")
   end

   local function wrap(fn)
      return function(...)
		return fn(self, unpack(arg))
      end
   end

   local names = {["help"]=wrap(self.help),
	          ["findnode"]=wrap(self.findnode),
	          ["gc"]=wrap(self.gc),
		  ["sha1"]=ec.sha1,
	          ["routing"]=wrap(self.routing),
	          ["print"]=print,
		  pprint=wrap(self.prettyprint),
		  add=wrap(self.add),
		  findvalue=wrap(self.findvalue),
	          xor=ec.xor,
	          tohex=ec.tohex,
	          fromhex=ec.fromhex,
		  getbucketno=ec.getbucketno}

   local env = {}
   for key,value in pairs(names) do
      env[key] = value
   end

   while true do
      local event = swaitforevent("stdin")
      if event.raw then
	 local chunk = loadstring(event.raw)
	 if chunk then
	    setfenv(chunk, env)
	    scall(chunk)
	 else
	    print("! syntax error")
	 end
      else
	 print("errno, errormessage", event.errno, event.errormessage)
      end
   end
end