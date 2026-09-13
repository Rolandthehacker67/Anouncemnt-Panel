-- Legacy chat variant: TextChatService is unavailable, so the panel must fall
-- back to Player.Chatted / Players.PlayerChatted only.
table.insert(MockPlayers, makePlayer("Steve", 11111, { [1234] = 255 }))
table.insert(MockPlayers, makePlayer("Bob", 22222))
Mock.setMode(true, false, false)
game._services.TextChatService = nil -- GetService now hands back a bare stub
print("[setup] legacy chat: TextChatService removed before boot")
