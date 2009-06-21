
local print = print

KademluaShell = {}

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
	          ["routing"]=wrap(self.routing)}

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