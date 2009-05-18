-- retrieved from https://svn.neurostechnology.com/hackers/daurnimator/lua/btorrent/libbencode.lua 
-- on 2009/05/10.

-- Michael Meier, 2009
-- added the encoding functions myself, fixed decode_list and decode_dict()

-- Thanks to prec in #lua for the majority of this.

-- Reference:
-- http://wiki.theory.org/BitTorrentSpecification#bencoding
 
local type_decoder
 
local function decode(s, pos)
	pos = pos or 1
	local dd = type_decoder[s:sub(pos,pos)]
	if not dd then
		error(string.format("encoding error at position %d: >>%s[...]<<",
			pos, s:sub(pos, pos + 10)))
	end
	return dd(s, pos)
end
 
local function decode_integer(s, pos)
	local _, pos, n = assert(s:find("^i(-?%d+)e", pos))
	return tonumber(n), pos+1 --rest
end
 
local function decode_string(s, pos)
	local _, pos, len = assert(s:find("^(%d+):", pos))
	return s:sub(pos + 1, pos + len), pos + len + 1
end
 
local function decode_list(s, pos)
	local _, pos = assert(s:find("^l.", pos))
	local a = {}
	while not s:match("^e", pos) do
		a[#a + 1], pos = decode(s, pos)
	end
	_, pos = assert(s:find("^e", pos))
	return a, pos + 1
end
 
local function decode_dict(s, pos)
	local _, pos = assert(s:find("^d.", pos))
	local d = {}
	while not s:match("^e", pos) do
		local k
		k, pos = decode(s, pos)
		-- i relaxed this a little bit from
		-- assert(type(k) == "string")
		-- to
		local tp = type(k)
		assert(tp == "string" or tp == "number")
		d[k], pos = decode(s, pos)
	end
	_, pos = assert(s:find("^e", pos))
	return d, pos + 1
end
 
type_decoder = {
	i = decode_integer, l = decode_list, d = decode_dict,
	["0"] = decode_string, ["1"] = decode_string,
	["2"] = decode_string, ["3"] = decode_string,
	["4"] = decode_string, ["5"] = decode_string,
	["6"] = decode_string, ["7"] = decode_string,
	["8"] = decode_string, ["9"] = decode_string,
}





--local _encode


local function islist(t)
   if type(t) ~= "table" then return false end
   -- has list elements and thus is a list
   if t[1] ~= nil then return true end
   
   local next, base, state = pairs(t)
   local key = next(base, state)
   
   if key == nil then 
      -- empty list
      return true 
   else
      -- has normal table entries
      return false
   end
end


local function isdict(t)
   if type(t) ~= "table" then return false end
   return not islist(t)
end

local encodelist, encodedict, encodeinteger, encodestring

local function _encode(data, chunks)
   local returnstring = false
   local chunks = chunks
   if chunks == nil then 
      returnstring = true
      chunks = {}
   end
   
   if type(data) == "number" then
      encodeinteger(data, chunks)
   elseif type(data) == "string" then
      encodestring(data, chunks)
   elseif type(data) == "table" then
      if islist(data) then
	 encodelist(data, chunks)
      else
	 encodedict(data, chunks)
      end
   end

   if returnstring then
      return table.concat(chunks)
   end
end


function encodeinteger(what, chunks)
   local insert = table.insert
   insert(chunks, "i")
   insert(chunks, tostring(what))
   insert(chunks, "e")
end

function encodestring(what, chunks)
   local insert = table.insert
   insert(chunks, tostring(#what))
   insert(chunks, ":")
   insert(chunks, what)
end

function encodelist(what, chunks)
   local insert = table.insert
   insert(chunks, "l")
   for i, v in ipairs(what) do
      --print("inserting into list")
      _encode(v, chunks)
   end
   insert(chunks, "e")
end

function encodedict(what, chunks)
   local insert = table.insert
   insert(chunks, "d")
   for key, val in pairs(what) do
      --print("inserting into dict")
      _encode(key, chunks)
      _encode(val, chunks)
   end
   insert(chunks, "e")
end












debencode = decode
bencode = _encode

print(_encode({"abc", 3, {a=10, b="11"}}))
