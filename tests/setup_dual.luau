-- Both halves in one process: the panel source is loaded twice, once with the
-- server flags and once with the client flags, sharing the same mock DataModel.
table.insert(MockPlayers, makePlayer("Steve", 11111, { [1234] = 255 }))
table.insert(MockPlayers, makePlayer("Bob", 22222))
Mock.setMode(true, false, false) -- first boot: SERVER
print("[setup] 2 players; booting the server half first")
