#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>


#include <sys/socket.h>
#include <arpa/inet.h>


//#include <poll.h>
#include <sys/select.h>


#include <openssl/sha.h>


#define DEFAULT_PORT 8000
#define HASH_SECT u_int32_t


lua_State *mstate;
int sock;
int port;
struct sockaddr_in mysockaddr;




static int getevent(lua_State *L) {

  
  fd_set rset;
  FD_ZERO(&rset);
  FD_SET(0,    &rset);
  FD_SET(sock, &rset);


  // determining max fd = argh! i hate apple for not being able to produce
  // a poll() which works on a terminal.
  select(sock + 1, &rset, NULL, NULL, 0);

  if (FD_ISSET(0, &rset)) {
    char buf[1024];
    buf[read(0, buf, 1023)] = 0;
    //printf("read: %s", buf);    
   
    //lua_pushstring(mstate, buf);

    lua_newtable(L);
    lua_pushstring(L, "from");
    lua_pushstring(L, "stdin");
    lua_settable(L, -3);

    lua_pushstring(L, "raw");
    lua_pushstring(L, buf);
    lua_settable(L, -3);
    
    return 1;
  }

  if (FD_ISSET(sock, &rset)) {
    char sbuf[16384];
    printf("socket ready to read\n");
    int res = read(sock, sbuf, 16384);
    if (res == -1) {
      perror("kademlua: read");
      return 0;
    }

    lua_newtable(L);
    lua_pushstring(L, "from");
    lua_pushstring(L, "sock");
    lua_settable(L, -3);

    lua_pushstring(L, "raw");
    lua_pushlstring(L, sbuf, res);
    lua_settable(L, -3);


    return 1;
  }


  return 0;

}


static int sha1(lua_State* L) {
  
  int nargs = lua_gettop(L);
  if (nargs != 1) {
    lua_pushstring(L, "sha1() needs exactly one argument");
    lua_error(L);
  }
  
  if (!(lua_isstring(L, 1))) {
    lua_pushstring(L, "argument needs to be a string");
    lua_error(L);
  }

  size_t len;
  const unsigned char *buf = (const unsigned char*) lua_tolstring(L, 1, &len);
  unsigned char *res = SHA1(buf, len, NULL);
  lua_pushlstring(L, (char *) res, 20);
  return 1;
}


char nibbledigit(char digit) {
  if ((digit >= 0) & (digit < 10)) {
    return digit + 48;
  } else if ((digit >= 10) & (digit < 16)) {
    return digit + 87;
  } else {
    return 'x';
  }
}

static int tohex(lua_State *L) {

  int nargs = lua_gettop(L);
  if (nargs != 1) {
    lua_pushstring(L, "sha1() needs exactly one argument");
    lua_error(L);
  }
  
  if (!(lua_isstring(L, 1))) {
    lua_pushstring(L, "argument needs to be a string");
    lua_error(L);
  }

  size_t len;
  const unsigned char *inbuf = (const unsigned char*) lua_tolstring(L, 1, &len);

  char* outbuf = malloc(len * 2);
  if (outbuf == NULL) {
    lua_pushstring(L, "could not allocate memory");
    lua_error(L);
  }
  
  for (int i = 0; i < len; i++) {
    outbuf[i*2 + 1] = nibbledigit(inbuf[i] & 0xf);
    outbuf[i*2] = nibbledigit((inbuf[i] >> 4) & 0xf);
  }

  lua_pushlstring(L, outbuf, len*2);
  return 1;

}


char fromdigit(char digit) {
  if ((digit >= 48) & (digit < 58)) {
    return digit -48;
  } else if ((digit >= 97) & (digit < 102)) {
    return digit - 87;
  } else {
    return 0;
  }
}


static int fromhex(lua_State *L) {

  int nargs = lua_gettop(L);
  if (nargs != 1) {
    lua_pushstring(L, "sha1() needs exactly one argument");
    lua_error(L);
  }
  
  if (!(lua_isstring(L, 1))) {
    lua_pushstring(L, "argument needs to be a string");
    lua_error(L);
  }

  size_t len;
  const unsigned char *inbuf = (const unsigned char*) lua_tolstring(L, 1, &len);

  unsigned char* outbuf = calloc((len / 2) + (len % 2), sizeof(unsigned char));
  if (outbuf == NULL) {
    lua_pushstring(L, "could not allocate memory");
    lua_error(L);
  }
  
  unsigned char shift;
  int offset;
  if (len % 2) {
    outbuf[0] = '0';
    shift = 0;
    offset = 1;
  } else {
    shift = 1;
    offset = 0;
  }

  for (int i = 0; i < len; i++) {
    unsigned char nibble = fromdigit(inbuf[i]);
    if (shift) {
      outbuf[(i + offset) / 2] |= (nibble << 4);
    } else {
      outbuf[(i + offset) / 2] |= (nibble);
    }
    shift = shift ^ 1;
  }

  lua_pushlstring(L, (char *) outbuf, (len/2) + (len % 2));
  return 1;

}


static int xor(lua_State *L) {

  int nargs = lua_gettop(L);
  if (nargs != 2) {
    lua_pushstring(L, "xor() needs exactly two arguments");
    lua_error(L);
  }
  
  if (!(lua_isstring(L, 1))) {
    lua_pushstring(L, "argument 1 needs to be a string");
    lua_error(L);
  }

  if (!(lua_isstring(L, 2))) {
    lua_pushstring(L, "argument 2 needs to be a string");
    lua_error(L);
  }

  size_t len1;
  const unsigned char *inbuf1 = (const unsigned char*) lua_tolstring(L, 1, &len1);

  size_t len2;
  const unsigned char *inbuf2 = (const unsigned char*) lua_tolstring(L, 2, &len2);


  if (len1 != len2) {
    lua_pushstring(L, "the strings need to be of the same length");
    lua_error(L);
  }

  if ((len1 % sizeof(HASH_SECT)) != 0) {
    lua_pushstring(L, "the strings need to be divideable by sizeof(HASH_SECT)");
    lua_error(L);
  }

  HASH_SECT *sect1 = (HASH_SECT*) inbuf1;
  HASH_SECT *sect2 = (HASH_SECT*) inbuf2;

  unsigned char* outbuf = malloc(len1);
  if (outbuf == NULL) {
    lua_pushstring(L, "could not allocate memory");
    lua_error(L);
  }

  HASH_SECT *outsect = (HASH_SECT*) outbuf;

  for (int i = 0; i < (len1 / sizeof(HASH_SECT)); i++) {
    outsect[i] = sect1[i] ^ sect2[i]; 
    printf("%x ^ %x == %x\n", sect1[i], sect2[i], sect1[i] ^ sect2[i]);
  }


  lua_pushlstring(L, (char*) outbuf, len1);
  return 1;

}




static const struct luaL_reg eclib[] = {
  {"getevent", getevent},
  {"sha1", sha1},
  {"tohex", tohex},
  {"fromhex", fromhex},
  {"xor", xor},
  {NULL, NULL}
};





int main(int argc, char **argv) {


  port = DEFAULT_PORT;

  mstate = lua_open();
  luaL_openlibs(mstate);
  luaL_openlib(mstate, "ec", eclib, 0);


  if ((sock = socket(PF_INET, SOCK_DGRAM, 0)) == -1) {
    perror("kademlua: socket");
    exit(1);
  }


  {
    int res;
    int on = 1;
    if ((res = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on))) == -1) {
      perror("kademlua: setsockopt");
      exit(1);
    }
  }
  

  {
    int res;
    mysockaddr.sin_addr.s_addr = INADDR_ANY;
    mysockaddr.sin_port = htons(port);
    if ((res = bind(sock, (struct sockaddr*) &mysockaddr, sizeof(mysockaddr))) == -1) {
      perror("kademlua: bind");
      exit(1);
    }

    socklen_t len = sizeof(mysockaddr);
    res = getsockname(sock, (struct sockaddr*) &mysockaddr, &len);
    if (res == -1) {
      perror("kademlua: getsockname");
    }
    char ascaddr[24];
    inet_ntop(AF_INET, &(mysockaddr.sin_addr), ascaddr, 24);
    printf("bound to %s:%i\n", ascaddr, ntohs(mysockaddr.sin_port));
  }

  /*getchar();*/

  {
    int res = luaL_loadfile(mstate, "kademlua.lua");
    if (res != 0) {
      printf("error loading kademlua.lua\n");
      exit(1);
    }

    lua_call(mstate, 0, 0);
  }

  return 0;

}
