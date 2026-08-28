# Lesson: Wide-Character Encoding in Legacy Exports Is a Common Silent-Corruption Source

If your legacy platform exports data from a Windows-native tool, don't assume UTF-8.
Some older tools (Lieberman/RED-IM's `PerAccountRules` export, for example) write
UTF-16 LE — every character followed by a null byte. PowerShell's default
`Get-Content` will "succeed" but silently mangle the data.

**Takeaway:** use `Get-Content -Encoding Unicode` and strip null bytes
(`-replace '\x00',''`) when parsing exports like this, and verify a sample row
manually before trusting a bulk parse.
