-- OxlynCrypto: pure-Lua SHA-256, HMAC-SHA256, and a nonce generator.
-- Requires Lua 5.3+ (native bitwise operators, string.pack/unpack).
-- Deobfuscated and cleaned from decompiler output.

local Crypto = {}

local MASK = 0xFFFFFFFF

-- SHA-256 round constants
local K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

-- SHA-256 initial hash values
local INITIAL_HASH = {
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

local char, byte, rep, format = string.char, string.byte, string.rep, string.format
local concat = table.concat

-- 32-bit rotate right
local function rotr(x, n)
  return ((x >> n) | (x << (32 - n))) & MASK
end

-- 32-bit integer -> 4-byte big-endian string
local function u32be(n)
  return char((n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF)
end

-- Raw SHA-256 (returns 32-byte binary string)
local function sha256Raw(msg)
  local len = #msg
  local padLen = (55 - len) % 64
  msg = msg .. char(0x80) .. rep(char(0), padLen)
          .. u32be((len >> 29) & MASK) .. u32be((len << 3) & MASK)

  local h0, h1, h2, h3, h4, h5, h6, h7 = table.unpack(INITIAL_HASH)
  local w = {}

  for chunk = 1, #msg, 64 do
    -- Message schedule
    for i = 0, 15 do
      w[i] = string.unpack(">I4", msg, chunk + i * 4)
    end
    for i = 16, 63 do
      local w15, w2 = w[i - 15], w[i - 2]
      local s0 = rotr(w15, 7) ~ rotr(w15, 18) ~ (w15 >> 3)
      local s1 = rotr(w2, 17) ~ rotr(w2, 19) ~ (w2 >> 10)
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & MASK
    end

    -- Compression
    local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
    for i = 0, 63 do
      local S1 = rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)
      local ch = (e & f) ~ (~e & g)
      local temp1 = (h + S1 + ch + K[i + 1] + w[i]) & MASK
      local S0 = rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)
      local maj = (a & b) ~ (a & c) ~ (b & c)
      local temp2 = (S0 + maj) & MASK

      h = g
      g = f
      f = e
      e = (d + temp1) & MASK
      d = c
      c = b
      b = a
      a = (temp1 + temp2) & MASK
    end

    h0 = (h0 + a) & MASK
    h1 = (h1 + b) & MASK
    h2 = (h2 + c) & MASK
    h3 = (h3 + d) & MASK
    h4 = (h4 + e) & MASK
    h5 = (h5 + f) & MASK
    h6 = (h6 + g) & MASK
    h7 = (h7 + h) & MASK
  end

  return u32be(h0) .. u32be(h1) .. u32be(h2) .. u32be(h3)
      .. u32be(h4) .. u32be(h5) .. u32be(h6) .. u32be(h7)
end

-- Binary string -> lowercase hex
function Crypto.tohex(s)
  local out = {}
  for i = 1, #s do
    out[i] = format("%02x", byte(s, i))
  end
  return concat(out)
end

-- Hex -> binary string (nil if input is not valid even-length hex)
function Crypto.fromhex(hex)
  if type(hex) ~= "string" or #hex % 2 ~= 0 or hex:find("[^%x]") then
    return nil
  end
  local out = {}
  for i = 1, #hex, 2 do
    out[#out + 1] = char(tonumber(hex:sub(i, i + 1), 16))
  end
  return concat(out)
end

Crypto.sha256Raw = sha256Raw

function Crypto.sha256(msg)
  return Crypto.tohex(sha256Raw(msg))
end

-- HMAC-SHA256 (raw binary output)
function Crypto.hmacRaw(key, msg)
  if #key > 64 then
    key = sha256Raw(key)
  end

  local ipad, opad = {}, {}
  for i = 1, 64 do
    local kb = byte(key, i) or 0
    ipad[i] = char(kb ~ 0x36)
    opad[i] = char(kb ~ 0x5C)
  end

  return sha256Raw(concat(opad) .. sha256Raw(concat(ipad) .. msg))
end

function Crypto.hmac(key, msg)
  return Crypto.tohex(Crypto.hmacRaw(key, msg))
end

-- Nonce generator: hashes a mix of counter, randomness, and timers
local nonceCounter = 0

function Crypto.nonce()
  nonceCounter = nonceCounter + 1

  local parts = {
    tostring(nonceCounter),
    tostring({}), -- table address as extra entropy
    tostring(math.random(0, 2147483647)),
    tostring(math.random(0, 2147483647)),
  }

  if os and os.time then parts[#parts + 1] = tostring(os.time()) end
  if os and os.clock then parts[#parts + 1] = tostring(os.clock()) end
  if GetGameTimer then parts[#parts + 1] = tostring(GetGameTimer()) end   -- FiveM
  if GetFrameTime then parts[#parts + 1] = tostring(GetFrameTime()) end   -- FiveM

  return Crypto.sha256(concat(parts, "|"))
end

OxlynCrypto = Crypto