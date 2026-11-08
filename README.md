# bulk-extractor-to-csv

Turn bulk_extractor's huge text output into CSV files you can filter, sort and search in **Timeline Explorer**, Excel or any other CSV tool.

![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-blue) ![Version](https://img.shields.io/badge/version-1.0.0-green) ![License: MIT](https://img.shields.io/badge/license-MIT-yellow)

---

## Why this exists

[bulk_extractor](https://github.com/simsong/bulk_extractor) scans raw data (memory images, pagefiles, disk images) and writes what it finds (URLs, domains, email addresses, JSON, carved records) to plain text files. On a single 32 GB memory image that means files like these:

| File | Size | Lines |
|---|---|---|
| `json.txt` | 208 MB | 431,000 |
| `url.txt` | 141 MB | 561,000 |
| `domain.txt` | 52 MB | 605,000 |

Notepad freezes on them, and most editors struggle. The files are also hard to read even when they open:
- Each line is tab-separated with no header row.
- Every file starts with `#` comment lines.
- Text found in UTF-16 shows up as `h\000t\000t\000p\000s`.

This script converts a whole bulk_extractor output folder to CSV in under a minute:
- adds a header row
- keeps the byte offset of every hit
- adds a **ContextClean** column that turns `h\000t\000t\000p\000s` back into `https`

The output is in the same format as the rest of a Windows forensic workflow, so you can work through it in Timeline Explorer.

## Quick start

```powershell
.\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem
```

The CSV files are written to `E:\Analysis\case01_mem\csv\`. The bulk_extractor folder itself is only read, never changed.

Only the files you need:

```powershell
.\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem -Only url,domain,email,url_searches
```

Measured on the output of a 32 GB memory image: 35 files, 2.2 million rows, **53 seconds**.

## Output

| bulk_extractor file | CSV columns |
|---|---|
| Feature files: `url.txt`, `domain.txt`, `email.txt`, `json.txt`, `ip.txt`, `winpe.txt`, the `*_carved.txt` files and the rest | `Offset, Feature, Context, ContextClean` |
| Count lists: `url_searches.txt`, `url_services.txt` (and the `*_histogram.txt` files with `-IncludeHistograms`) | `Count, Feature, Notes` |

📖 **The [user guide](docs/USER_GUIDE.md)** explains:
- every parameter and column
- a workflow for reading bulk_extractor output
- quick searches with `grep` or PowerShell, and how to read large files
- stop lists, and handling the output as evidence

## Requirements

- Windows PowerShell 5.1 (built into Windows 10 and 11) or PowerShell 7.
- A bulk_extractor output folder. bulk_extractor itself can run anywhere (Windows, Linux, WSL, the SIFT Workstation): the script only reads its files.

No modules and no installs. The script makes no network calls.

## Related

- [windows-dfir-collector](https://github.com/seliyyah/windows-dfir-collector) (Collect_v3): the Windows live-response collector whose memory images and pagefiles this was first written for. Section 10 of its user guide covers where to point bulk_extractor.

## Credits

- **bulk_extractor**, by **Simson Garfinkel** and contributors: https://github.com/simsong/bulk_extractor
- **Timeline Explorer**, by **Eric Zimmerman**: https://ericzimmerman.github.io

Neither tool is included here; this script only reads bulk_extractor's output.

## License

[MIT](LICENSE). Provided as-is, without warranty. bulk_extractor output can contain personal data and key material: handle it according to your evidence-handling policies.
