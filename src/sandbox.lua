--------------------------------------------------------------------------
-- Lmod License
--------------------------------------------------------------------------
--
--  Lmod is licensed under the terms of the MIT license reproduced below.
--  This means that Lua is free software and can be used for both academic
--  and commercial purposes at absolutely no cost.
--
--  ----------------------------------------------------------------------
--
--  Copyright (C) 2008-2013 Robert McLay
--
--  Permission is hereby granted, free of charge, to any person obtaining
--  a copy of this software and associated documentation files (the
--  "Software"), to deal in the Software without restriction, including
--  without limitation the rights to use, copy, modify, merge, publish,
--  distribute, sublicense, and/or sell copies of the Software, and to
--  permit persons to whom the Software is furnished to do so, subject
--  to the following conditions:
--
--  The above copyright notice and this permission notice shall be
--  included in all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.
--
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Sandbox: Modulefiles are "loaded" in a sandbox.  That is when the module
--          file is evaluated, it can only run a limited set of functions.
--          This file provides for a default list of functions that can be
--          run.  There is also a sandbox_registration so that sites using
--          SitePackage can register their functions. Finally there are two
--          versions of run function one for Lua 5.1 and another for Lua 5.2
--          The appropriate version is assigned to [[sandbox_run]].

require("strict")
require("fileOps")
require("capture")
require("cmdfuncs")
require("modfuncs")
require("utils")
local posix = require("posix")

sandbox_run = false


--------------------------------------------------------------------------
-- Table containing valid functions for modulefiles.
sandbox_env = {
  require  = require,
  ipairs   = ipairs,
  next     = next,
  pairs    = pairs,
  pcall    = pcall,
  tonumber = tonumber,
  tostring = tostring,
  type     = type,
  unpack   = unpack or table.unpack,
  string   = { byte = string.byte, char = string.char, find = string.find,
               format = string.format, gmatch = string.gmatch, gsub = string.gsub,
               len = string.len, lower = string.lower, match = string.match,
               rep = string.rep, reverse = string.reverse, sub = string.sub,
               upper = string.upper },
  table    = { insert = table.insert, remove = table.remove, sort = table.sort,
               concat = table.concat, unpack = table.unpack, sqrt = math.sqrt,
               tan = math.tan, tanh = math.tanh },
  os       = { clock = os.clock, difftime = os.difftime, time = os.time, date = os.date,
               getenv = os.getenv},

  io       = { stderr = io.stderr, open = io.open, close = io.close, write = io.write },

  ------------------------------------------------------------
  -- lmod functions
  ------------------------------------------------------------

  --- Load family functions ----

  load                 = load_module,
  try_load             = try_load,
  try_add              = try_load,
  unload               = unload,
  always_load          = always_load,
  always_unload        = always_unload,

  --- PATH functions ---
  prepend_path         = prepend_path,
  append_path          = append_path,
  remove_path          = remove_path,

  --- Set Environment functions ----
  setenv               = setenv,
  pushenv              = pushenv,
  unsetenv             = unsetenv,

  --- Property functions ----
  add_property         = add_property,
  remove_property      = remove_property,

  --- Set Alias/shell functions ---
  set_alias            = set_alias,
  unset_alias          = unset_alias,
  set_shell_function   = set_shell_function,
  unset_shell_function = unset_shell_function,

  --- Prereq / Conflict ---
  prereq               = prereq,
  prereq_any           = prereq_any,
  conflict             = conflict,

  --- Family function ---
  family               = family,

  --- Inherit function ---
  inherit              = inherit,

  -- Whatis / Help functions
  whatis               = whatis,
  help                 = help,

  -- Misc --
  LmodError            = LmodError,
  LmodWarning          = LmodWarning,
  LmodMessage          = LmodMessage,
  is_spider            = is_spider,
  mode                 = mode,
  isloaded             = isloaded,
  isPending            = isPending,
  myFileName           = myFileName,
  myModuleFullName     = myModuleFullName,
  myModuleUsrName      = myModuleUsrName,
  myModuleName         = myModuleName,
  myModuleVersion      = myModuleVersion,
  hierarchyA           = hierarchyA,

  -- Normal modulefiles should not use these function(s):
  LmodSystemError      = LmodSystemError,   -- Normal Modulefiles should use
                                            -- LmodError instead.  LmodError
                                            -- is inactive during avail and spider.
                                            -- This function ALWAYS produces an
                                            -- error.
  ------------------------------------------------------------
  -- fileOp functions
  ------------------------------------------------------------
  pathJoin             = pathJoin,
  isDir                = isDir,
  isFile               = isFile,
  mkdir_recursive      = mkdir_recursive,
  dirname              = dirname,
  extname              = extname,
  removeExt            = removeExt,
  barefilename         = barefilename,
  splitFileName        = splitFileName,
  abspath              = abspath,
  path_regularize      = path_regularize,

  ------------------------------------------------------------
  -- lfs functions
  ------------------------------------------------------------
  lfs = { attributes = lfs.attributes, chdir = lfs.chdir, lock_dir = lfs.lock_dir,
          currentdir = lfs.currentdir, dir = lfs.dir, lock = lfs.lock,
          mkdir = lfs.mkdir, rmdir = lfs.rmdir, rmdir = lfs.rmdir,
          setmode = lfs.setmode, symlinkattributes = lfs.symlinkattributes,
          touch = lfs.touch, unlock = lfs.unlock,
  },

  ------------------------------------------------------------
  -- posix functions
  ------------------------------------------------------------
  posix = { uname = posix.uname, setenv = posix.setenv,
            hostid = posix.hostid, open = posix.open,
            openlog = posix.openlog, closelog = posix.closelog,
            syslog = posix.syslog, },

  ------------------------------------------------------------
  -- Misc functions
  ------------------------------------------------------------
  capture              = capture,
  UUIDString           = UUIDString,
  ------------------------------------------------------------
  -- Misc System Values
  ------------------------------------------------------------
  _VERSION             = _VERSION,
}

--------------------------------------------------------------------------
-- sandbox_registration(): Sites should call this function if they have
--                         functions inside their SitePackage.lua file for
--                         any functions that they want that are callable
--                         via their modulefiles.

function sandbox_registration(t)
   if (type(t) ~= "table") then
      LmodError("sandbox_registration: The argument passed is: \"", type(t),
                "\". It should be a table.")
   end
   for k,v in pairs(t) do
      sandbox_env[k] = v
   end
end


--------------------------------------------------------------------------
-- sandbox_run(): Define two version: Lua 5.1 or 5.2.  It is likely that
--                The 5.2 version will be good for many new versions of
--                Lua but time will only tell.

-- This function is what actually "loads" a modulefile with protection
-- against modulefiles call functions they shouldn't or syntax errors
-- of any kind.


local function run5_1(untrusted_code)
  if untrusted_code:byte(1) == 27 then return nil, "binary bytecode prohibited" end
  local untrusted_function, message = loadstring(untrusted_code)
  if not untrusted_function then return nil, message end
  setfenv(untrusted_function, sandbox_env)
  return pcall(untrusted_function)
end

-- run code under environment [Lua 5.2]
local function run5_2(untrusted_code)
  local untrusted_function, message = load(untrusted_code, nil, 't', sandbox_env)
  if not untrusted_function then return nil, message end
  return pcall(untrusted_function)
end

sandbox_run = (_VERSION == "Lua 5.1") and run5_1 or run5_2


