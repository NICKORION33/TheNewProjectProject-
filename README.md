# NIQWARES Universal Agent Development Framework


A cross‑agent collaborative development framework designed so **ChatGPT, Claude, Gemini, and any future CLI‑capable AI agents** can seamlessly continue each other’s work, share context, follow the same rules, and iteratively improve a project together.


This repository provides:
- A **universal bootstrap protocol** for all agent CLIs
- A **structured instruction system** to prevent accidental overwrites or context loss
- A **task, subtask, goal, and test result schema** shared across all agent types
- A **backup and audit pipeline** ensuring transparent, reversible, attributions‑tracked changes
- A baseline collaboration environment enabling agents to hand off work cleanly

## 🚀 Purpose (Concise Summary)
This project establishes a clean, deterministic operational framework enabling AI agents to:
- Safely modify files
- Resume development where another agent left off
- Document intention, changes, tests, and results in a standardized format
- Cooperatively iterate on features, fixes, and architecture

All while maintaining full human oversight and cryptographically verifiable backups.

## 🧭 Use Cases
- **Cross‑agent continuity:** Have Gemini continue a task GPT-5.1 started; let Claude refactor code written by ChatGPT; let GPT pick up an unfinished feature from Gemini.
- **Deterministic multi‑agent workflows:** Enforce structured procedures so all agents behave predictably.
- **Distributed feature development:** Parallel tasks across agents using shared schemas.
- **Automated auditing:** Every action is logged, hashed, attributed, and reversible.
- **Agent‑driven DevOps:** Agents can run bootstrap, test, backup, commit, PR, and changelog updates.
- **Research sandbox:** Experiment with comparing agent approaches on a controlled timeline.

## 📌 Current State of Development
- ✓ Core bootstrap protocol defined
- ✓ Backup and metadata engine implemented (`tooling/backup.ps1`)
- ✓ Agent initialization audit logging implemented (`tooling/bootstrap.ps1`)
- ✓ Repo structure, logs, changelog, and conventions in place
- ✓ Git hooks template included
- ✓ Cross‑agent continuity rules documented in `AUTO_BOOTSTRAP.md`

**Next planned improvements:**
- Unified agent runner wrapper for all AI CLIs
- JSON schemas for tasks, intentions, test results, and failure conditions
- Multi‑agent “handoff bundles”
- GitHub Actions CI integration

## 📥 Download / Clone

  git clone https://github.com//.git cd

If you want to include this framework inside an existing repo:
  
  git submodule add https://github.com//.git niqwares-agent-framework

## 🤝 Contributing
Contributions are welcome—human or agent.

Ways to help:
- Improve schemas and structured instructions
- Add more CLI wrappers (Gemini, Claude, etc.)
- Add tests or compatibility layers
- Expand DevOps tooling
- Refine or expand the bootstrap protocol
- Submit issues with logs from your agent workflows

To contribute:
1. Fork the repository
2. Create a feature branch
3. Follow the backup/commit/audit rules in `AUTO_BOOTSTRAP.md`
4. Open a Pull Request


## 🌐 Project Vision
This framework aims to become a **universal, model‑agnostic foundation** for multi-agent iterative software development. A future where:
- Agents build complex systems together.
- Every update is versioned, logged, reversible, and testable.
- Human developers direct and supervise while agents perform structured work.
- Tools remain open, transparent, and interoperable.


This repo is the first step toward that ecosystem.
