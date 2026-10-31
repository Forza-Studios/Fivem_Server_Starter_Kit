OxlynProtocol = {
  VERSION = "1",

  -- Key-derivation context strings
  DERIVE_SERVER = "oxlyn-lib/server/",
  DERIVE_CLIENT = "oxlyn-lib/client/",

  -- Token context strings
  TOKEN_SERVER = "oxlyn-lib/token-server/",
  TOKEN_CLIENT = "oxlyn-lib/token-client/",

  -- Handshake message types
  HELLO = "hello",
  WELCOME = "welcome",

  -- Nonce lifetime in seconds (15 minutes)
  NONCE_TTL = 900,
}