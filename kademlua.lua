
print("hash of 'kademlua':", ec.tohex(ec.sha1("kademlua")))
print("with fromhex:", ec.tohex(ec.fromhex(ec.tohex(ec.sha1("kademlua")))))


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
