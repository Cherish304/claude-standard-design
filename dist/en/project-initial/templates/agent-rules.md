## File spec (full text in SPEC.md)
- Read INDEX.md before starting a task. Only files registered in INDEX.md count as evidence.
- Treat only files with status active or done as evidence. Draft is for reference only. Superseded and abandoned are not evidence unless the user names them.
- Before creating a file, look in INDEX.md. When an active file on the same subject exists, edit it; do not create a copy.
- Do not use final, new, latest, copy, old, tmp, v2 and similar words in file names, and no copy suffix like (1).
- Update INDEX.md in the same operation whenever you create, change the status of, archive or delete a file, and after pulling an external repo.
- External repos live in external/, one folder per version. Use them read-only: do not edit files in them, commit in them or switch branches. Pull a new version into a new folder; never update a folder in place. Before using one, check that the commit in INDEX.md matches the local one. When the last-checked date is older than 30 days, check the remote first as described in SPEC.md section 12.4. Pulling a new version or deleting a folder needs the user's confirmation.
- Never write credentials (tokens, passwords) when recording a remote address.
- Do not change the conclusion of a done experiment, or a config or dataset that a result refers to.
- Do not delete files. When cleanup is needed, list the candidates and wait for the user's confirmation. Moving a file to archive/ is allowed directly.
