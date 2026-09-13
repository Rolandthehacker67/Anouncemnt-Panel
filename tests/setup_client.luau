-- Runs BEFORE the panel boots. Client-only install: no server remotes exist, so
-- the panel must fall back to SOLO mode and drive everything locally.
table.insert(MockPlayers, makePlayer("Steve", 11111, { [1234] = 255 }))
Mock.setMode(false, true, true) -- client context, Studio
print("[setup] 1 local player (owner), no server remotes -> expect SOLO mode")
