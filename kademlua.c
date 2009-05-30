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

#include <sys/time.h>
#include <sys/errno.h>



/* kademlua.c 
 * (C) 2009, Michael Meier
 */



#define DEFAULT_PORT 8000
#define HASH_SECT u_int32_t


lua_State *mstate;
int sock;
int port;
struct sockaddr_in mysockaddr;
int readfromstdin;

void notdecoded(lua_State *L) {

    lua_pushstring(L, "decoded");
    lua_pushboolean(L, 0);
    lua_settable(L, -3);

}

static int recvpacket(lua_State *L) {

  char sbuf[16384];
  //printf("socket ready to read\n");

  struct sockaddr_in from;

  socklen_t len = sizeof(from);
  int res = recvfrom(sock, sbuf, 16384, 0,
		     (struct sockaddr *) &from, &len);
  if (res == -1) {
    perror("kademlua: read");
    return 0;
  }

  //int packlen = res;


  char ascaddr[32] = {0};
  inet_ntop(AF_INET, &(from.sin_addr), ascaddr, sizeof(ascaddr));


  lua_newtable(L);
  lua_pushstring(L, "type");
  lua_pushstring(L, "sock");
  lua_settable(L, -3);
  
  lua_pushstring(L, "raw");
  lua_pushlstring(L, sbuf, res);
  lua_settable(L, -3);

  lua_pushstring(L, "from");
  lua_newtable(L);
  lua_pushstring(L, "addr");
  lua_pushstring(L, ascaddr);
  lua_settable(L, -3);
  
  lua_pushstring(L, "port");
  lua_pushnumber(L, ntohs(from.sin_port));
  lua_settable(L, -3);
  lua_settable(L, -3);
  //printf("addr stored\n");
  
  

  /*int pos = 0;
  if (packlen < 1) {
    notdecoded(L);
    return 1;
  } else {
    if (sbuf[0] != 1) {
      // wrong header type
      notdecoded(L);
      return 1;
    }
    // we need 21 more bytes
    pos++;
    if (packlen < (pos + 21)) {
      notdecoded(L);
      return 1;
    }

    char *idptr = &sbuf[pos];

    pos = pos + 20;
    unsigned char call = sbuf[pos];

    lua_pushstring(L, "message");
    lua_newtable(L);

    lua_pushstring(L, "id");
    lua_pushlstring(L, idptr, 20);
    lua_settable(L, -3);


    lua_pushstring(L, "from");
    lua_newtable(L);


    lua_pushstring(L, "addr");
    lua_pushstring(L, ascaddr);
    lua_settable(L, -3);

    lua_pushstring(L, "port");
    lua_pushnumber(L, ntohs(from.sin_port));
    lua_settable(L, -3);

    lua_pushstring(L, "id");
    lua_pushlstring(L, idptr, 20);
    lua_settable(L, -3);

    char unique[64];
    snprintf(unique, 64, "%s:%i:", ascaddr, ntohs(from.sin_port));
    {
      lua_pushstring(L, "unique");
      int where = strlen(unique);
      if (where <= 44) {
	memcpy(&unique[where], idptr, 20);
	lua_pushlstring(L, unique, where + 20);
      } else {
	lua_pushstring(L, "xxx");
      }
      lua_settable(L, -3);
    }



    lua_settable(L, -3);


    lua_pushstring(L, "call");
    lua_pushnumber(L, call);
    lua_settable(L, -3);


    lua_settable(L, -3);



    lua_pushstring(L, "decoded");
    lua_pushboolean(L, 1);
    lua_settable(L, -3);

    }*/

  return 1;

}


static int getevent(lua_State *L) {

  int nargs = lua_gettop(L);

  double dtimeout;
  if (nargs >= 1) {
    dtimeout = lua_tonumber(L, 1);
  } else {
    dtimeout = 0;
  }


  struct timeval timeout;
  struct timeval *timeout_ptr;
  if (dtimeout == 0.0) {
    timeout_ptr = NULL;
  } else {
    timeout.tv_sec = (int) dtimeout;
    timeout.tv_usec = (int) ((dtimeout - (double) ((int) dtimeout)) * 1e6);
    timeout_ptr = &timeout;
  }

  
  if (nargs >= 2) {
    
    int packslen = lua_objlen(L, 2);

    for (int i = 1; i <= packslen; i++) {
      lua_pushnumber(L, i);
      lua_gettable(L, 2);
      // -> packet table on top of stack
      //printf("got packet table\n");
      
      lua_pushstring(L, "to");
      lua_gettable(L, -2);
      // -> to field on top of stack
      //printf("got to field\n");

      lua_pushstring(L, "addr");
      lua_gettable(L, -2);
      // -> ip addr on top of stack
      //printf("ip addr string on top of stack\n");

      const char *ascaddr = lua_tostring(L, -1);
      if (ascaddr == NULL) {
	lua_pushstring(L, "need a string to represent and IP address");
	lua_error(L);
      }

      struct sockaddr_in addr;
      addr.sin_family = AF_INET;
      if (inet_pton(AF_INET, ascaddr, &(addr.sin_addr)) == -1) {
	lua_pushstring(L, "invalid IP address");
	lua_error(L);
      }

      //printf("got addr\n");

      lua_pop(L, 1);
      // -> to field on top of stack
      
      lua_pushstring(L, "port");
      lua_gettable(L, -2);
      // -> port on top of stack
      addr.sin_port = htons(lua_tonumber(L, -1));
      lua_pop(L, 1);
      // -> to field on top of stack

      lua_pop(L, 1);
      // -> packet table on top of stack

      lua_pushstring(L, "raw");
      lua_gettable(L, -2);
      int sendres;
      if (!(lua_isnil(L, -1))) {
	size_t len;
	const char *raw = lua_tolstring(L, -1, &len);
	sendres = sendto(sock, raw, len, 0, 
			 (struct sockaddr*) &addr, sizeof(addr));
      } else {
	sendres = sendto(sock, "yeehaw!", 7, 0, 
			 (struct sockaddr*) &addr, sizeof(addr));
      }
      lua_pop(L, 1);

      if (sendres == -1) {
	char *errmsg = strerror(errno);
	lua_pushstring(L, "errmsg");
	lua_pushstring(L, errmsg);
	lua_settable(L, -3);

	lua_pushstring(L, "errno");
	lua_pushnumber(L, errno);
	lua_settable(L, -3);
      }
      lua_pushstring(L, "res");
      lua_pushnumber(L, sendres);
      lua_settable(L, -3);

      lua_pop(L, 1);
      // -> last arg on top of stack
    }

  }


  fd_set rset;
  FD_ZERO(&rset);
  if (readfromstdin)
    FD_SET(0,    &rset);
  FD_SET(sock, &rset);


  // determining max fd = argh! i hate apple for not being able to produce
  // a poll() which works on a terminal.
  select(sock + 1, &rset, NULL, NULL, timeout_ptr);

  if (FD_ISSET(0, &rset)) {
    char buf[1024];
    int bytesread = read(0, buf, 1023);
    if (bytesread == -1) {
      lua_newtable(L);

      lua_pushstring(L, "type");
      lua_pushstring(L, "stdin");
      lua_settable(L, -3);

      lua_pushstring(L, "errno");
      lua_pushnumber(L, (double) errno);
      lua_settable(L, -3);

      lua_pushstring(L, "errormessage");
      lua_pushstring(L, strerror(errno));
      lua_settable(L, -3);

      return 1;
    }
    buf[bytesread] = 0;
    if (bytesread == 0) 
      readfromstdin = 0;
    //printf("read: %s", buf);    
   
    //lua_pushstring(mstate, buf);

    lua_newtable(L);
    lua_pushstring(L, "type");
    lua_pushstring(L, "stdin");
    lua_settable(L, -3);

    lua_pushstring(L, "raw");
    lua_pushstring(L, buf);
    lua_settable(L, -3);
    
    return 1;
  }

  if (FD_ISSET(sock, &rset)) {

    return recvpacket(L);
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
  free(outbuf);
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
  free(outbuf);
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
    //printf("%x ^ %x == %x\n", sect1[i], sect2[i], sect1[i] ^ sect2[i]);
  }


  lua_pushlstring(L, (char*) outbuf, len1);
  free(outbuf);
  return 1;

}


static int getbucketno(lua_State* L) {
  
  int nargs = lua_gettop(L);
  if (nargs != 1) {
    lua_pushstring(L, "getbucketno() needs exactly one argument");
    lua_error(L);
  }
  
  if (!(lua_isstring(L, 1))) {
    lua_pushstring(L, "argument needs to be a string");
    lua_error(L);
  }

  size_t len;
  const unsigned char *buf = (const unsigned char*) lua_tolstring(L, 1, &len);

  for (int i = 0; i < len; i++) {
    unsigned char bit = 1;
    // we have found the byte with the first bit set (in the string as a whole)
    unsigned char byte = buf[i];
    if (byte) {
      while (!(byte & 0x80)) {
	byte = byte << 1;
	bit++;
      }
      lua_pushnumber(L, (double) (i * 8) + (double) bit);
      return 1;
    }
  }

  lua_pushnumber(L, 161);
  return 1;

  // the error will not be in your face
  //lua_pushstring(L, "no bit set to one found");
  //lua_error(L);
  return 0;

}


static int ectime(lua_State *L) {
  
  struct timeval t;

  gettimeofday(&t, NULL);

  double tm = t.tv_sec + (1e-6 * t.tv_usec);

  lua_pushnumber(L, tm);
  return 1;

}



static const struct luaL_reg eclib[] = {
  {"getevent", getevent},
  {"sha1", sha1},
  {"tohex", tohex},
  {"fromhex", fromhex},
  {"xor", xor},
  {"getbucketno", getbucketno},
  {"time", ectime},
  {NULL, NULL}
};





int main(int argc, char **argv) {

  readfromstdin = 1;
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
    lua_newtable(mstate);
    for (int i = 0; i < argc; i++) {
      lua_pushnumber(mstate, i);
      lua_pushstring(mstate, argv[i]);
      lua_settable(mstate, -3);
    }
    lua_setglobal(mstate, "argv");
  }

  int res = luaL_loadfile(mstate, "params.lua");
  if (res != 0) {
    printf("error loading params.lua\n");
    exit(1);
  }

  lua_call(mstate, 0, 0);

  lua_getglobal(mstate, "port");
  if (!lua_isnumber(mstate, -1)) {
    printf("port variable not correctly set in params.lua");
    exit(1);
  }
  
  port = (int) lua_tonumber(mstate, -1);

  lua_settop(mstate, 0);
  


  {
    int res;
    mysockaddr.sin_family = AF_INET;
    mysockaddr.sin_addr.s_addr = INADDR_ANY;
    
    // TODO: move somewhere else
    //mysockaddr.sin_addr.s_addr = inet_addr("192.168.1.5");
    

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
    char ascaddr[32];
    inet_ntop(AF_INET, &(mysockaddr.sin_addr), ascaddr, 32);
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
