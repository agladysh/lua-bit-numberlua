--[[

LUA MODULE

  bit.numberlua - Bitwise operations implemented in pure Lua as numbers.

SYNOPSIS

  local bit = require 'bit.numberlua'
  print(bit.band(0xff00ff00, 0x00ff00ff)) --> 0xffffffff
  
  -- Interface providing strong Lua 5.2 'bit32' compatibility
  local bit32 = require 'bit.numberlua'.bit32
  assert(bit32.band(-1) == 0xffffffff)
  
DESCRIPTION
  
  This library implements bitwise operations entirely in Lua.
  This module is typically intended if for some reasons you don't want
  to or cannot  install a popular C based bit library like BitOp 'bit' [1]
  (which comes pre-installed with LuaJIT) or 'bit32' (which comes
  pre-installed with Lua 5.2) but want a similar interface.
  
  This modules represents bit arrays as non-negative Lua numbers. [1]
  It can represent 32-bit bit arrays when Lua is compiled
  with lua_Number as double-precision IEEE 754 floating point.

  The module is nearly the most efficient it can be but may be a few times
  slower than the C based bit libraries and is orders or magnitude
  slower than LuaJIT bit operations, which compile to native code.  Therefore,
  this library is inferior in performane to the other modules.

  The `xor` function in this module is based partly on Roberto Ierusalimschy's
  post in http://lua-users.org/lists/lua-l/2002-09/msg00134.html .
  
  The included BIT.bit32 sublibrary aims to provide 100% compatibility with
  the Lua 5.2 "bit32" library.  This compatbility is at the cost of some
  efficiency since inputted numbers are normalized and more general
  forms (e.g. multi-argument bitwise operators) are supported.
  
STATUS

  WARNING: Not all corner cases have been tested and documented.
  Some attempt was made to make these similar to the Lua 5.2 [2]
  and LuaJit BitOp [3] libraries, but this is not fully tested and there
  are currently some differences.  Addressing these differences may
  be improved in the future but it is not yet fully determined how to
  resolve these differences.
  
  The BIT.bit32 library passes the Lua 5.2 test suite (bitwise.lua)
  http://www.lua.org/tests/5.2/ .

API

  BIT.tobit(x) --> z
  
    Similar to function in BitOp.
    
  BIT.tohex(x, n)
  
    Similar to function in BitOp.
  
  BIT.band(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.
  
  BIT.bor(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.

  BIT.bxor(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.
  
  BIT.bnot(x) --> z
  
    Similar to function in Lua 5.2 and BitOp.

  BIT.lshift(x, disp) --> z
  
    Similar to function in Lua 5.2 (warning: BitOp uses unsigned lower 5 bits of shift),
  
  BIT.rshift(x, disp) --> z
  
    Similar to function in Lua 5.2 (warning: BitOp uses unsigned lower 5 bits of shift),

  BIT.extract(x, field [, width]) --> z
  
    Similar to function in Lua 5.2.
  
  BIT.replace(x, v, field, width) --> z
  
    Similar to function in Lua 5.2.
  
  BIT.bswap(x) --> z
  
    Similar to function in Lua 5.2.

  BIT.rrotate(x, disp) --> z
  BIT.ror(x, disp) --> z
  
    Similar to function in Lua 5.2 and BitOp.

  BIT.lrotate(x, disp) --> z
  BIT.rol(x, disp) --> z

    Similar to function in Lua 5.2 and BitOp.
  
  BIT.arshift
  
    Similar to function in Lua 5.2 and BitOp.
    
  BIT.btest
  
    Similar to function in Lua 5.2 with requires two arguments.

  BIT.bit32
  
    This table contains functions that aim to provide 100% compatibility
    with the Lua 5.2 "bit32" library.
    
    bit32.arshift (x, disp) --> z
    bit32.band (...) --> z
    bit32.bnot (x) --> z
    bit32.bor (...) --> z
    bit32.btest (...) --> true | false
    bit32.bxor (...) --> z
    bit32.extract (x, field [, width]) --> z
    bit32.replace (x, v, field [, width]) --> z
    bit32.lrotate (x, disp) --> z
    bit32.lshift (x, disp) --> z
    bit32.rrotate (x, disp) --> z
    bit32.rshift (x, disp) --> z
    
DEPENDENCIES

  None (other than Lua 5.1 or 5.2).
    
INSTALLATION

  Copy the `bit` directory into your LUA_PATH.

REFERENCES

  [1] http://lua-users.org/wiki/FloatingPoint
  [2] http://www.lua.org/manual/5.2/
  [3] http://bitop.luajit.org/
  
LICENSE

  (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)

--]]

local M = {_TYPE='module', _NAME='bit.numberlua', _VERSION='000.003.2011-11-29'}

local floor = math.floor

local MOD = 2^32
local MODM = MOD-1

local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k); t[k] = v
    return v
  end
  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t[am][bm]*p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a+b)*p
    return res
  end
  return bitop
end

local function make_bitop(t)
  local op1 = make_bitop_uncached(t,2^1)
  local op2 = memoize(function(a)
    return memoize(function(b)
      return op1(a, b)
    end)
  end)
  return make_bitop_uncached(op2, 2^(t.n or 1))
end

-- ok?  probably not if running on a 32-bit int Lua number type platform
function M.tobit(x)
  return x % 2^32
end

M.bxor = make_bitop {[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4}
local bxor = M.bxor

function M.bnot(a)   return MODM - a end
local bnot = M.bnot

function M.band(a,b) return ((a+b) - bxor(a,b))/2 end
local band = M.band

function M.bor(a,b)  return MODM - band(MODM - a, MODM - b) end
local bor = M.bor

local lshift, rshift -- forward declare

function M.rshift(a,disp) -- Lua5.2 insipred
  if disp < 0 then return lshift(a,-disp) end
  return floor(a % 2^32 / 2^disp)
end
rshift = M.rshift

function M.lshift(a,disp) -- Lua5.2 inspired
  if disp < 0 then return rshift(a,-disp) end 
  return (a * 2^disp) % 2^32
end
lshift = M.lshift

function M.tohex(x, n) -- BitOp style
  n = n or 8
  local up
  if n < 0 then
    up = true
    n = - n
  end
  x = band(x, 16^n-1)
  return ('%0'..n..(up and 'X' or 'x')):format(x)
end

function M.extract(n, field, width) -- Lua5.2 inspired
  width = width or 1
  return band(rshift(n, field), 2^width-1)
end
local extract = M.extract

function M.replace(n, v, field, width) -- Lua5.2 inspired
  width = width or 1
  local mask1 = 2^width-1
  v = band(v, mask1) -- required by spec?
  local mask = bnot(lshift(mask1, field))
  return band(n, mask) + lshift(v, field)
end
local replace = M.replace

function M.bswap(x)  -- BitOp style
  local a = band(x, 0xff); x = rshift(x, 8)
  local b = band(x, 0xff); x = rshift(x, 8)
  local c = band(x, 0xff); x = rshift(x, 8)
  local d = band(x, 0xff)
  return lshift(lshift(lshift(a, 8) + b, 8) + c, 8) + d
end

function M.rrotate(x, disp)  -- Lua5.2 inspired
  disp = disp % 32
  local low = band(x, 2^disp-1)
  return rshift(x, disp) + lshift(low, 32-disp)
end
local rrotate = M.rrotate

function M.lrotate(x, disp)  -- Lua5.2 inspired
  return rrotate(x, -disp)
end
local lrotate = M.lrotate

M.rol = M.lrotate  -- LuaOp inspired
M.ror = M.rrotate  -- LuaOp insipred


function M.arshift(x, disp) -- Lua5.2 inspired
  local z = rshift(x, disp)
  if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
  return z
end

function M.btest(x, y) -- Lua5.2 inspired
  return band(x, y) ~= 0
end

--
-- Start Lua 5.2 "bit32" compat section.
--

M.bit32 = {} -- Lua 5.2 'bit32' compatibility


local function bit32_bnot(x)
  return (-1 - x) % MOD
end
M.bit32.bnot = bit32_bnot

local function bit32_bxor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = bxor(a, b)
    if c then
      z = bxor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end
M.bit32.bxor = bit32_bxor

local function bit32_band(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = ((a+b) - bxor(a,b)) / 2
    if c then
      z = band(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return MODM
  end
end
M.bit32.band = bit32_band

local function bit32_bor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = MODM - band(MODM - a, MODM - b)
    if c then
      z = bor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end
M.bit32.bor = bit32_bor

function M.bit32.btest(...)
  return bit32_band(...) ~= 0
end

function M.bit32.lrotate(x, disp)
  return lrotate(x % MOD, disp)
end

function M.bit32.rrotate(x, disp)
  return rrotate(x % MOD, disp)
end

function M.bit32.lshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return lshift(x % MOD, disp)
end

function M.bit32.rshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return rshift(x % MOD, disp)
end

function M.bit32.arshift(x,disp)
  x = x % MOD
  if disp >= 0 then
    if disp > 31 then
      return (x >= 0x80000000) and MODM or 0
    else
      local z = rshift(x, disp)
      if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
      return z
    end
  else
    return lshift(x, -disp)
  end
end

function M.bit32.extract(x, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  return extract(x, field, ...)
end

function M.bit32.replace(x, v, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  v = v % MOD
  return replace(x, v, field, ...)
end


-- TODO? Likewise add  LuaOp "bit" compat section?
-- M.bit32 = {} -- LuaOp "bit" compatibility


return M
