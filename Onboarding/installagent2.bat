if not exist \\AUIFW-DC01\c$\dkbtools md \\AUIFW-DC01\c$\dkbtools
copy c:\windows\ltsvc\agent.exe \\AUIFW-DC01\c$\dkbtools\agent_install.exe /y
psexec \\AUIFW-DC01 -accepteula -s c:\windows\ltsvc\agent.exe /s