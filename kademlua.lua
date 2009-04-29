require("protocol")
require("scheduler")


s1 = Scheduler:new()

print("s1:", s1.readyq)


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


function f2()
   return "retval f2"
end

function printn(n)
   for i=1,n do
      print("i is now: " .. tostring(i))
      syield()
      ssleep(1.8)
   end
end

function f1()
   srun(printn, 3)
   ssleep(2.0)
   syield()
   errorfree, ret = scall(f2)
   return "retval f1", ret
end
s1:runf(f1, "arg1", "and arg 2")

-- wait for all coroutines to finish
--while(s1:runone() > 0) do print(); print() end
s1:run()

res = ec.getevent()

print("the res table:")
table.foreach(res, print)
print("")
print("res.type: " .. res.type)

if res.type == "stdin" then
   print("from stdin")
elseif res.type == "sock" then
   print("from socket")
   table.foreach(res, print)
   if res.decoded then
      table.foreach(res.message, print)
      print("from:")
      table.foreach(res.message.from, print)
   end
else
   print("unknown from")
end
