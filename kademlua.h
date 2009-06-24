#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
//#include <unistd.h>

#include <sys/socket.h>
#include <arpa/inet.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/*
      kademlua.h
      (c) 2009, Michael Meier
*/


struct eventstate {
  lua_State *mstate;
  int sock;
  u_int16_t port;
  struct sockaddr_in mysockaddr;
  int readfromstdin;
};


void notdecoded(lua_State *L);
int recvpacket(lua_State *L, struct eventstate *estate);
int getevent(lua_State *L);
int sha1(lua_State *L);
char nibbledigit(char digit);
int tohex(lua_State *L);
char fromdigit(char digit);
int fromhex(lua_State *L);
int xor(lua_State *L);
int getbucketno(lua_State *L);
int ectime(lua_State *L);
void pushargv(lua_State *L, int argc, char **argv);
int initestate(lua_State *L);
struct eventstate *init(int argc, char **argv);

static const struct luaL_reg eclib[];
