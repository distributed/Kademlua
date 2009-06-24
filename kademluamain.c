#include <stdio.h>
#include "kademlua.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/* kademluamain.c
   (c) 2009 Michael Meier */


int main(int argc, char **argv) {


  struct eventstate *estate = init(argc, argv);
  if (!estate) {
    printf("init failed\n");
    exit(1);
  }
  /*getchar();*/

  lua_State *mstate = estate->mstate;

  /* init pushed the estate userdata on the stack, push it into the
     lua namespace */
  lua_setglobal(mstate, "estate");

  {
    int res = luaL_loadfile(estate->mstate, "kademlua.lua");
    if (res != 0) {
      printf("error loading kademlua.lua\n");
      exit(1);
    }

    lua_call(estate->mstate, 0, 0);
  }

  return 0;

}
