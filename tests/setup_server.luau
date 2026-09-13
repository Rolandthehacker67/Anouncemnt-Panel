-- Runs BEFORE the panel boots, so the server sees a populated player list.
table.insert(MockPlayers, makePlayer("Steve", 11111, { [1234] = 255 }))
table.insert(MockPlayers, makePlayer("Bob", 22222))
Mock.setMode(true, false, false) -- server context, not Studio (real rank rules)
print("[setup] 2 players created, server mode, studio=false")
