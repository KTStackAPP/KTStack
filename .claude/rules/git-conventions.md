# Git & GitHub conventions

- Branches: `feat/<short-kebab-topic>`. Never push a `claude/...` branch; if the environment assigns one, create a `feat/` branch instead and work there.
- Commits: Conventional Commits (`feat:`, `fix:`, `refactor:`, `ci:` …), authored as the repo identity `Nguyên Khôi <vanngelttt@gmail.com>`. If `git config user.name` is `Claude`, set the local identity before committing.
- No AI attribution anywhere: no `Co-Authored-By: Claude`, no `Claude-Session:` trailer, no "Generated with/by Claude Code" line or link, in commit messages, PR titles/bodies, PR/issue comments or reviews. If a tool appends such a footer after posting, edit it back out.
