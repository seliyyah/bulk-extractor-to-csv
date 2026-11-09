# Changelog

All notable changes to `Convert-BeToCsv.ps1`. Format based on [Keep a Changelog](https://keepachangelog.com/); versions follow [Semantic Versioning](https://semver.org/).

## [1.0.1]

### Changed
- License changed from MIT to BSD 3-Clause. The script header carries the copyright and SPDX lines; the README adds "Sharing and redistributing" and Disclaimer sections. No change to what the script does.

## [1.0.0]

First release.

- Converts every bulk_extractor `.txt` output file in a folder to CSV with a header row.
- Detects the two layouts: feature files (`Offset, Feature, Context, ContextClean`) and count lists (`Count, Feature, Notes`).
- `ContextClean` removes the `\000` escapes so UTF-16 text is readable.
- `-Only`, `-OutputPath` and `-IncludeHistograms` parameters.
- UTF-8 output with a byte-order mark, for Excel and Timeline Explorer.
- Tested on bulk_extractor 2.2.1 output from a 32 GB memory image: 35 files, 2.2 million rows in 53 seconds under Windows PowerShell 5.1.
