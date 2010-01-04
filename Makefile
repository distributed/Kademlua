# Makefile for Kademlua
# 
# (C) 2010, Michael Meier
#
# builds only a standalone binary
# for shared librariers, see bottom

# edit those to point to your lua/openssl installation
LUA_INCLUDE=-I/opt/local/include
LUA_LIB=-L/opt/local/lib -llua

SSL_INCLUDE=-I/usr/include
SSL_LIB=-L/usr/lib -lcrypto



DEBUG=-g
OPT=-O0


CFLAGS=-Wall $(DEBUG) $(OPT) -std=c99 $(LUA_INCLUDE) $(SSL_INCLUDE)
LDFLAGS=$(LUA_LIB) $(SSL_LIB)




all: standalone #shared


shared:
	@echo shared lib compiling not implemented yet


standalone: kademlua

kademlua: kademlua.o kademluamain.o


clean:
	rm -f *.o
	rm -f kademlua
	rm -rf kademlua.dSYM







# shared libraries should be something like:


#$LIBTOOL --mode=compile gcc -Wall $DEBUG kademlua.c -I /opt/local/include -c -o kademlua.o -std=c99 -O3 || exit 1
#$LIBTOOL --mode=compile gcc -Wall $DEBUG kademluamain.c -I /opt/local/include -c -o kademluamain.o -std=c99 -O3 || exit 1

#$LIBTOOL --mode=link gcc -o libkademlua.la kademlua.lo -rpath $(pwd) -lcrypto
#$LIBTOOL --mode=link gcc -o kademlua kademlua.lo kademluamain.lo -lcrypto -L/opt/local/lib -llua

# where $LIBTOOL == glibtool or something like that