
print("hash of 'kademlua':", ec.tohex(ec.sha1("kademlua")))
print("with fromhex:", ec.tohex(ec.fromhex(ec.tohex(ec.sha1("kademlua")))))

-- this xors
-- 1111 0101 1100 1010 0.....
-- 1111 0011 0000 0011 0.....
-- --------------------------
-- 0000 0110 1100 1001 0.....
--    0    6    c    0 0.....
xorres = ec.xor(ec.fromhex("f5ca0000"), ec.fromhex("f3030000"))
print("xor:", ec.tohex(xorres))
-- seems to be working :P

print("this would be put in bucket " .. tostring(ec.getbucketno(xorres)))
-- seems to be correct too



res = ec.getevent()

print("the res table:")
table.foreach(res, print)
print("")
print("res.from: " .. res.from)

if res.from == "stdin" then
   print("from stdin")
elseif res.from == "sock" then
   print("from socket")
else
   print("unknown from")
end
