# Argument Parser Templates

This directory contains Argbash templates for generating argument parsers.

## What is Argbash?

[Argbash](https://argbash.io/) is a bash code generator that generates argument parsing code from templates. It provides:
- Automatic help generation
- Type validation
- Consistent error messages
- Professional CLI interface

## Prerequisites

Install argbash via Homebrew:

```bash
brew install argbash
```

Or install all project dependencies:

```bash
brew bundle install
```

## Generating the Argument Parser

### Quick Start

Use the generation script:

```bash
./templates/generate-parser.sh
```

This will:
1. Check if argbash is installed
2. Generate `lib/args-parser.sh` from the template
3. Validate the generated code

### Manual Generation

If you prefer to generate manually:

```bash
argbash templates/reset-args.m4 -o lib/args-parser.sh
```

## Template Structure

The template `reset-args.m4` defines all arguments for the `reset-file-associations.sh` script:

### Boolean Flags
- `--dry-run` / `-d`: Dry run mode
- `--verbose` / `-v`: Verbose output
- `--no-throttle`: Disable throttling
- `--no-confirm`: Skip confirmations
- `--no-parallel`: Disable parallel processing
- `--skip-sampling`: Skip sampling phase

### Single-Value Options
- `--path` / `-p PATH`: Target directory
- `--max-files N`: Maximum files limit
- `--max-rate N`: Rate limit
- `--max-memory N`: Memory limit
- `--batch-size N`: Batch size
- `--workers N`: Worker count
- `--chunk-size N`: Chunk size
- `--sample-size N`: Sample size
- `--log-level LEVEL`: Log level
- `--log-file PATH`: Log file path

### Repeated Options
- `--ext` / `-e EXT`: File extensions (can be used multiple times)

### Positional Arguments
- `DIRECTORY`: Target directory (optional, defaults to `.`)

## Integration

The generated parser exports all parsed arguments as environment variables for use by the main script:

```bash
# In main script
source lib/args-parser.sh

# Use parsed arguments
if [[ "$DRY_RUN" = "on" ]]; then
  echo "Running in dry-run mode"
fi
```

## Validation

The template includes comprehensive validation:
- Integer validation for numeric options
- Enum validation for log levels
- Directory existence checks
- Extension normalization (removes leading dots)

## Modifying the Template

To add new arguments:

1. Edit `templates/reset-args.m4`
2. Add new ARG_* directives following Argbash syntax
3. Update validation in `validate_arguments()`
4. Update exports in `export_arguments()`
5. Regenerate the parser

### Argbash Directives

- `ARG_OPTIONAL_BOOLEAN([name], [short], [description])`
- `ARG_OPTIONAL_SINGLE([name], [short], [description], [default])`
- `ARG_OPTIONAL_REPEATED([name], [short], [description], [default])`
- `ARG_POSITIONAL_SINGLE([name], [description], [default])`

## Resources

- [Argbash Documentation](https://argbash.readthedocs.io/)
- [Argbash Examples](https://github.com/matejak/argbash/tree/master/resources/examples)
- [Argbash Online](https://argbash.io/generate) - Web-based generator

## Troubleshooting

### "argbash: command not found"

Install argbash:
```bash
brew install argbash
```

### Generated parser has syntax errors

Check the template for:
- Unmatched brackets
- Missing m4 directives
- Invalid ARG_ declarations

### Parser not exporting variables correctly

Verify:
- `export_arguments()` function includes all variables
- Variable names match the main script's expectations
- Array variables are properly quoted
