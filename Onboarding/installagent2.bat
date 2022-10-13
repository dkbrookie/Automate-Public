if not exist \\%1\c$\dkbtools md \\A%1\c$\dkbtools
copy c:\windows\ltsvc\agent.exe \\%1\c$\dkbtools\agent_install.exe /y
psexec \\%1 -accepteula -s c:\windows\ltsvc\agent.exe /s
