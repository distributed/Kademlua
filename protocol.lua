rpcidlength = 8

-- packet table -> binary string
function encodepacket(info, headervers)

   local chunks = {}
   
   if headervers == nil then
      hv = 1
   else
      if headervers == 1 then
	 hv = 1
      else
	 error("unsupported header version")
      end
   end


   table.insert(chunks, string.char(hv))

   if hv == 1 then
      local rpcid = info.rpcid
      local fromid = info.fromid
      local call = info.call

      if #rpcid ~= rpcidlength then error("rpcid has to be 8 bytes long") end
      if #fromid ~= 20 then error("fromid has to be 20 bytes long") end
      if call > 255 or call < 0 then error("call has to be a character number") end

      table.insert(chunks, fromid)
      table.insert(chunks, rpcid)
      table.insert(chunks, string.char(call))
   else

   end

   return table.concat(chunks)

end


-- raw packet table -> packet table
function decodepacket(packet)

   packet.decoded = false
   local raw = packet.raw

   local hv = string.byte(raw:sub(1, 1))

   if hv == 1 then
      local fromid = raw:sub(2, 21)
      local rpcid = raw:sub(22, 29)
      local call = raw:sub(30, 30)
      --print("decoding header type 1")
      --print("fromid " .. fromid)
      --print("rpcid " .. rpcid)
      --print("call " .. call)
      if call == "" then return end

      call = string.byte(call)
      
      packet.from.id = fromid
      packet.from.unique = packet.from.addr .. ":" .. packet.from.port .. ":" .. fromid
      packet.rpcid = rpcid
      packet.call = call
      packet.decoded = true
      return
   else
      return
   end


end