
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


function KademluaShell:findnode(argtable)
   local id = argtable[2]

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


function KademluaShell:main()
   local errorfree, errmsg = sregisterforevent("stdin")
   print("KademluaShell: register:", errorfree, errmsg)
   if not errorfree then
      error("KademluaShell could not register for stdin event")
   end

   local names = {["help"]=self.help,
	          ["findnode"]=self.findnode,
                 }

   while true do
      local event = swaitforevent("stdin")
      if event.raw then
	 local env = {}
	 for key,value in pairs(names) do
	    env[key] = value
	 end

	 local chunk = loadstring("args = {" .. event.raw .. "}")
	 if chunk then
	    setfenv(chunk, env)
	    pcall(chunk)
	    local args = env.args
	    
	    if args[1] then
	       if type(args[1] == "function") then
		  scall(args[1], self, args)
	       else
		  print("not a valid command")
	       end
	    else
	       print("! no command specified")
	    end
	 else
	    print("! syntax error")
	 end
      else
	 print("errno, errormessage", event.errno, event.errormessage)
      end
   end
end