# User guide

**bulk-extractor-to-csv** version 1.0.1

1. [Running the script](#1-running-the-script)
2. [What comes out](#2-what-comes-out)
3. [A workflow for bulk_extractor output](#3-a-workflow-for-bulk_extractor-output)
4. [Quick searches without opening anything](#4-quick-searches-without-opening-anything)
5. [Very large files](#5-very-large-files)
6. [Cutting the noise: stop lists](#6-cutting-the-noise-stop-lists)
7. [Handling the output](#7-handling-the-output)
8. [Troubleshooting](#8-troubleshooting)

The examples use `E:\Analysis\case01_mem` as the bulk_extractor output folder (the folder given to `bulk_extractor -o`). Replace it with your own.

---

## 1. Running the script

```powershell
.\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem
```

| Parameter | What it does | Default |
|---|---|---|
| `-Folder` (or `-Path`) | The bulk_extractor output folder. Required. | |
| `-Only url,domain,email` | Convert only these files (names without `.txt`). | all files |
| `-OutputPath <folder>` | Where to write the CSV files. | `<Folder>\csv` |
| `-IncludeHistograms` | Also convert the `*_histogram.txt` files. They are small and readable as they are, so they're skipped by default. | off |

At the end the script prints one line per file (layout, rows, seconds) and the output folder.

**If Windows won't run the script** ("running scripts is disabled on this system", or a warning about a file downloaded from the internet), either unblock it once:

```powershell
Unblock-File .\Convert-BeToCsv.ps1
```

or run it with a one-off bypass that changes no system setting:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem
```

---

## 2. What comes out

One CSV per bulk_extractor file, with the same name (`url.txt` → `url.csv`). The files are UTF-8 with a byte-order mark, so Excel and Timeline Explorer show non-English text correctly.

### Feature files → `Offset, Feature, Context, ContextClean`

Most bulk_extractor files list one hit per line: where it was found, what was found, and the bytes around it.

| Column | Meaning |
|---|---|
| `Offset` | Byte offset of the hit in the file bulk_extractor scanned (the memory image, pagefile or disk image). A form like `81256448-GZIP-1032` means the hit is 1,032 bytes into data that bulk_extractor decompressed at offset 81,256,448. Use the offset to jump to the spot in a hex editor, or to tie a hit to other tools that work with physical offsets. |
| `Feature` | What was found: the URL, domain, email address, JSON fragment, file path and so on. |
| `Context` | The bytes around the hit, exactly as bulk_extractor wrote them. Bytes that aren't printable text are written as escapes: `\000` is a zero byte, `\240` is byte 0xA0 (octal). |
| `ContextClean` | `Context` with the `\000` escapes removed. Text that was stored as UTF-16 (common in Windows memory) becomes readable: `h\000t\000t\000p\000s` → `https`. Other escapes are kept. |

### Count lists → `Count, Feature, Notes`

`url_searches.txt`, `url_services.txt`, `url_facebook-*.txt` and the `*_histogram.txt` files are already summaries: each line is a count and a value, most frequent first.

| Column | Meaning |
|---|---|
| `Count` | How many times the value was found. |
| `Feature` | The value: a search term, a service, a domain. |
| `Notes` | Anything bulk_extractor added, such as `(utf16=9346)`: how many of the hits were UTF-16 text. |

### Which files matter most

| File | What's in it |
|---|---|
| `url.txt`, `domain.txt` | Web addresses and site names anywhere in the data |
| `url_searches.txt` | Search terms typed into search engines |
| `email.txt`, `rfc822.txt` | Email addresses; email headers |
| `ip.txt`, `tcp.txt`, `ether.txt` | IP addresses, network connections and MAC addresses found in packet fragments (`packets.pcap` has the packets themselves) |
| `json.txt` | JSON fragments from apps and web pages |
| `winpe.txt`, `winpe_carved.txt` | Windows executables found in the data |
| `winlnk.txt`, `windirs.txt` | Shortcut (LNK) files; Windows folder entries |
| `evtx_carved.txt`, `ntfsmft_carved.txt`, `ntfsusn_carved.txt`, `ntfslogfile_carved.txt`, `ntfsindx_carved.txt` | Event log records and NTFS records still present in the data, often older than the live copies |
| `aes_keys.txt` | Encryption keys found in memory. Sensitive, see section 7. |
| `ccn.txt`, `sin.txt`, `pii.txt`, `telephone.txt` | Card numbers, ID numbers, other personal data, phone numbers. In memory images most `ccn` and `sin` hits are false positives (random numbers that pass the check digit). |

### Opening the CSVs

- **Timeline Explorer** (free, Eric Zimmerman) opens all of them, including the 600,000-row ones. Drag a column header to the grouping bar to group, type in the filter row under a header to filter, and press Ctrl+F to search all columns.
- **Excel** stops at 1,048,576 rows, which is enough for most files from a single image but not always. Excel also changes long numbers (offsets) into scientific notation when it opens a CSV directly; use Data → From Text/CSV and set the `Offset` column to Text.

---

## 3. A workflow for bulk_extractor output

1. **Read the histograms first.** `domain_histogram.txt`, `url_histogram.txt`, `email_histogram.txt` and `ip_histogram.txt` are small and already sorted by count. Skim the top to learn what's normal for this machine, then **read the bottom**: values seen only once or twice are where something unusual hides.
2. **Look up anything interesting in the feature files.** Open `url.csv` or `domain.csv` in Timeline Explorer, filter `Feature` on the value, and read `ContextClean` to see what surrounded it: a page that was visited, an ad, a config file, a log line.
3. **Read `url_searches.csv`.** Short and often revealing: it's what was being searched for.
4. **Check `winpe.csv`** for executable names that are misspelled, out of place, or in unusual folders.
5. **Open `packets.pcap` in Wireshark** (Statistics → Conversations) and compare it with `tcp.csv`.
6. **Tie hits to processes and times** with a memory analysis tool such as Volatility 3 or MemProcFS (for example the network connections and command lines), or with the other artifacts collected from the same machine. bulk_extractor tells you *what* is in the data; those tools tell you *who* and *when*.

**Build a baseline.** Run bulk_extractor once on a clean machine of the same build. In a real case, the useful question is what's in the suspect's output that isn't in the baseline.

---

## 4. Quick searches without opening anything

For a one-off question ("does `example.com` appear anywhere, and in which URLs?") a command is faster than opening a CSV. Both versions below search a bulk_extractor `.txt` file directly; no conversion is needed.

### The two parts you change

Every search uses the same command. You change only two things:

- **The search term:** what you're looking for. In the examples it is `whateverSEARCHTERMyouneed`: replace it with a domain, a name, an IP address, a file name, any text. Capitals don't matter.
- **The file:** which bulk_extractor file to look in. Each holds one kind of thing: `url.txt` (full web addresses), `domain.txt` (site names), `email.txt` (email addresses), `json.txt` (data fragments), `ip.txt` (IP addresses), and so on (see the table in section 2).

The result is a list with the most frequent matches first. The number is how many times each one was found:

```text
    412 https://www.example.com/
     37 https://www.example.com/login
      2 https://cdn.example.com/script.js
```

### With grep (Linux, WSL, SIFT, macOS)

Template:

```bash
grep -i -F 'whateverSEARCHTERMyouneed' /mnt/e/Analysis/case01_mem/url.txt | cut -f2 | sort | uniq -c | sort -rn | head -30
```

What each part does (you never need to change these):

| Part | Does |
|---|---|
| `grep -i -F '…'` | Finds lines containing the term. `-i` ignores capitals; `-F` takes the term literally, so the dots in `example.com` are dots and not "any character". |
| `cut -f2` | Keeps just the hit (column 2), dropping the offset and context. |
| `sort \| uniq -c` | Counts duplicates. |
| `sort -rn` | Puts the biggest counts first. |
| `head -30` | Shows the top 30. Use `head -100` for more, or remove it to see everything. |

In WSL, Windows drives are under `/mnt/`: `E:\Analysis` is `/mnt/e/Analysis`. From a PowerShell window, wrap the command like this (the distribution name is whatever `wsl -l` shows):

```powershell
wsl -d Ubuntu-24.04 -e bash -c "grep -i -F 'whateverSEARCHTERMyouneed' /mnt/e/Analysis/case01_mem/url.txt | cut -f2 | sort | uniq -c | sort -rn | head -30"
```

Examples:

```bash
# Every URL on example.com
grep -i -F 'example.com' /mnt/e/Analysis/case01_mem/url.txt | cut -f2 | sort | uniq -c | sort -rn | head -30

# Every email address at example.com
grep -i -F '@example.com' /mnt/e/Analysis/case01_mem/email.txt | cut -f2 | sort | uniq -c | sort -rn | head -30

# Every domain that contains your term
grep -i -F 'whateverSEARCHTERMyouneed' /mnt/e/Analysis/case01_mem/domain.txt | cut -f2 | sort | uniq -c | sort -rn | head -30

# JSON fragments mentioning example.com, with the full line (offset, fragment) rather than a count
grep -i -F 'example.com' /mnt/e/Analysis/case01_mem/json.txt | head -20

# Count all hits for a term in one file
grep -i -F -c 'example.com' /mnt/e/Analysis/case01_mem/url.txt
```

### With PowerShell only (no WSL)

Template:

```powershell
Select-String -Path E:\Analysis\case01_mem\url.txt -SimpleMatch 'whateverSEARCHTERMyouneed' |
    ForEach-Object { $_.Line.Split("`t")[1] } | Group-Object -NoElement |
    Sort-Object Count -Descending | Select-Object -First 30 |
    ForEach-Object { '{0,7} {1}' -f $_.Count, $_.Name }
```

It gives the same list as the grep version. `-SimpleMatch` takes the term literally, and `Select-String` ignores capitals by default.

Examples:

```powershell
# Every URL on example.com
Select-String -Path E:\Analysis\case01_mem\url.txt -SimpleMatch 'example.com' | ForEach-Object { $_.Line.Split("`t")[1] } | Group-Object -NoElement | Sort-Object Count -Descending | Select-Object -First 30 | ForEach-Object { '{0,7} {1}' -f $_.Count, $_.Name }

# Every email address at example.com
Select-String -Path E:\Analysis\case01_mem\email.txt -SimpleMatch '@example.com' | ForEach-Object { $_.Line.Split("`t")[1] } | Group-Object -NoElement | Sort-Object Count -Descending | Select-Object -First 30 | ForEach-Object { '{0,7} {1}' -f $_.Count, $_.Name }

# Which files mention your term at all, and how often
Select-String -Path E:\Analysis\case01_mem\*.txt -SimpleMatch 'whateverSEARCHTERMyouneed' | Group-Object Filename -NoElement | Sort-Object Count -Descending | ForEach-Object { '{0,7} {1}' -f $_.Count, $_.Name }
```

To search a different scan (a pagefile or disk image run), change the folder in the path.

---

## 5. Very large files

Even as CSV, `json.csv` or `url.csv` from a large image can be hundreds of MB. For reading rather than filtering, use a viewer built for large files instead of an editor:

- **klogg** (free, open source): opens multi-GB files instantly, fast search, highlights matches.
- **EmEditor** (commercial, free trial): opens very large files and edits CSV as a grid.

Notepad freezes on files this size, and even VS Code is slow above a few hundred MB.

---

## 6. Cutting the noise: stop lists

Most of the hits in a memory image are normal: Microsoft, certificate authorities, your browser's own pages. bulk_extractor can take a **stop list** of values you've already judged harmless. It moves matching hits to separate `*_stopped.txt` files, so the main files only hold what's left to look at.

Build one from a baseline run: take the top of `domain_histogram.txt`, keep the domains you recognize as normal, one per line, in a text file. Then add `-w` to the next run:

```bash
bulk_extractor -w /mnt/e/Analysis/stoplist.txt -o /mnt/e/Analysis/case02_mem /mnt/e/Evidence/case02_memory.raw
```

The stopped hits aren't lost; they're in the `*_stopped.txt` files if you need them. This script converts those too.

---

## 7. Handling the output

bulk_extractor output is evidence, and it is sensitive:

- `aes_keys.txt` holds real encryption key material found in memory (for example TLS sessions or disk encryption).
- `email.txt`, `telephone.txt`, `ccn.txt`, `sin.txt`, `pii.txt` and the URL files hold personal data and browsing history.

Store the CSVs with the rest of the case, under the same access controls, and don't share them outside the investigation. The script writes the CSVs only where you tell it to (by default inside the bulk_extractor folder), makes no network calls and changes nothing in the source folder.

---

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| "running scripts is disabled on this system" | See section 1: `Unblock-File`, or run with `-ExecutionPolicy Bypass -File`. |
| Warning "No report.xml" | The folder isn't a bulk_extractor output folder, or `report.xml` was moved. The script carries on and converts any `.txt` files it finds. |
| "No matching bulk_extractor .txt files found" | Check the folder path, and the names given to `-Only` (no `.txt`, e.g. `-Only url`). Empty files are skipped. |
| A file is missing from the output | It held only `#` comment lines (bulk_extractor found nothing), so there was nothing to convert. |
| Offsets look like `8.12564E+07` | Excel converted them. Open the CSV through Data → From Text/CSV and set `Offset` to Text, or use Timeline Explorer. |
| Strange characters in `Context` | Those are bulk_extractor's byte escapes (`\000`, `\240`, `\377`). Read `ContextClean` instead; for the raw bytes, jump to the offset in a hex editor. |
