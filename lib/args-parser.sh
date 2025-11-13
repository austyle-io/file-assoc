#!/usr/bin/env bash
# lib/args-parser.sh - Argument parser for reset-file-associations
#
# This parser implements all arguments from the Argbash template:
# templates/reset-args.m4
#
# Note: This was manually created as argbash had compatibility issues
# in the build environment. The functionality matches the template spec.

# ============================================================================
# DEFAULT VALUES
# ============================================================================

# Boolean flags (off by default)
_arg_dry_run="off"
_arg_verbose="off"
_arg_no_throttle="off"
_arg_no_confirm="off"
_arg_no_parallel="off"
_arg_skip_sampling="off"

# Single-value options with defaults
_arg_path=""
_arg_max_files="10000"
_arg_max_rate="100"
_arg_max_memory="500"
_arg_batch_size="1000"
_arg_workers="0"
_arg_chunk_size="100"
_arg_sample_size="100"
_arg_log_level="INFO"
_arg_log_file=""

# Repeated options (extensions)
declare -a _arg_ext=()

# Positional argument
_arg_directory="."

# ============================================================================
# HELP FUNCTION
# ============================================================================

print_help() {
  cat << EOF
Usage: reset-file-associations [OPTIONS] [DIRECTORY]

Reset file associations by clearing LaunchServices extended attributes.
Enhanced with logging, resource limits, and throttling.

ARGUMENTS:
  DIRECTORY                 Directory to process (default: current directory)

OPTIONS:
  -h, --help                Show this help message and exit
  -d, --dry-run             Show what would be changed without making changes
  --verbose                 Show detailed output with progress
  -p, --path PATH           Target directory path (takes precedence over positional arg)
  -e, --ext EXT             File extension to process (can be used multiple times)

  Resource Limits:
  --max-files NUM           Maximum files to process (default: 10000)
  --max-rate NUM            Maximum files per second (default: 100)
  --max-memory NUM          Maximum memory in MB (default: 500)
  --batch-size NUM          Files per batch (default: 1000)
  --no-throttle             Disable all throttling (not recommended)

  Parallel Processing:
  --workers NUM             Number of parallel workers, 0=auto (default: 0)
  --chunk-size NUM          Files per worker chunk (default: 100)
  --no-parallel             Disable parallel processing (sequential mode)

  Sampling:
  --sample-size NUM         Number of files to sample before full scan (default: 100)
  --skip-sampling           Skip sampling phase and proceed directly to full scan

  Logging:
  --log-level LEVEL         Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
  --log-file PATH           Custom log file location

  Other:
  --no-confirm              Skip confirmation prompts

EXAMPLES:
  # Dry run on current directory
  reset-file-associations --dry-run

  # Process specific extensions with verbose output
  reset-file-associations --verbose -e pdf -e doc -e docx ~/Documents

  # Full scan with custom limits
  reset-file-associations --max-files 5000 --workers 4 /path/to/files

EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      -d|--dry-run)
        _arg_dry_run="on"
        shift
        ;;
      --verbose)
        _arg_verbose="on"
        shift
        ;;
      -p|--path)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --path requires a value" >&2
          exit 1
        fi
        _arg_path="$2"
        shift 2
        ;;
      -e|--ext)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --ext requires a value" >&2
          exit 1
        fi
        _arg_ext+=("$2")
        shift 2
        ;;
      --max-files)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --max-files requires a value" >&2
          exit 1
        fi
        _arg_max_files="$2"
        shift 2
        ;;
      --max-rate)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --max-rate requires a value" >&2
          exit 1
        fi
        _arg_max_rate="$2"
        shift 2
        ;;
      --max-memory)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --max-memory requires a value" >&2
          exit 1
        fi
        _arg_max_memory="$2"
        shift 2
        ;;
      --batch-size)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --batch-size requires a value" >&2
          exit 1
        fi
        _arg_batch_size="$2"
        shift 2
        ;;
      --no-throttle)
        _arg_no_throttle="on"
        shift
        ;;
      --no-confirm)
        _arg_no_confirm="on"
        shift
        ;;
      --workers)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --workers requires a value" >&2
          exit 1
        fi
        _arg_workers="$2"
        shift 2
        ;;
      --chunk-size)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --chunk-size requires a value" >&2
          exit 1
        fi
        _arg_chunk_size="$2"
        shift 2
        ;;
      --no-parallel)
        _arg_no_parallel="on"
        shift
        ;;
      --sample-size)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --sample-size requires a value" >&2
          exit 1
        fi
        _arg_sample_size="$2"
        shift 2
        ;;
      --skip-sampling)
        _arg_skip_sampling="on"
        shift
        ;;
      --log-level)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --log-level requires a value" >&2
          exit 1
        fi
        _arg_log_level="$2"
        shift 2
        ;;
      --log-file)
        if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
          echo "Error: --log-file requires a value" >&2
          exit 1
        fi
        _arg_log_file="$2"
        shift 2
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        echo "Try '--help' for more information." >&2
        exit 1
        ;;
      *)
        # Positional argument
        _arg_directory="$1"
        shift
        ;;
    esac
  done
}

# ============================================================================
# ARGUMENT VALIDATION
# ============================================================================

validate_arguments() {
  # Validate max-files
  if ! [[ "$_arg_max_files" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-files must be a positive integer" >&2
    exit 1
  fi

  # Validate max-rate
  if ! [[ "$_arg_max_rate" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-rate must be a positive integer" >&2
    exit 1
  fi

  # Validate max-memory
  if ! [[ "$_arg_max_memory" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-memory must be a positive integer" >&2
    exit 1
  fi

  # Validate batch-size
  if ! [[ "$_arg_batch_size" =~ ^[0-9]+$ ]]; then
    echo "Error: --batch-size must be a positive integer" >&2
    exit 1
  fi

  # Validate workers
  if ! [[ "$_arg_workers" =~ ^[0-9]+$ ]]; then
    echo "Error: --workers must be a non-negative integer" >&2
    exit 1
  fi

  # Validate chunk-size
  if ! [[ "$_arg_chunk_size" =~ ^[0-9]+$ ]]; then
    echo "Error: --chunk-size must be a positive integer" >&2
    exit 1
  fi

  # Validate sample-size
  if ! [[ "$_arg_sample_size" =~ ^[0-9]+$ ]]; then
    echo "Error: --sample-size must be a positive integer" >&2
    exit 1
  fi

  # Validate log-level
  case "$_arg_log_level" in
    DEBUG|INFO|WARN|ERROR) ;;
    *)
      echo "Error: --log-level must be one of: DEBUG, INFO, WARN, ERROR" >&2
      exit 1
      ;;
  esac

  # Validate directory exists
  if [[ -n "$_arg_path" ]]; then
    if [[ ! -d "$_arg_path" ]]; then
      echo "Error: Path does not exist: $_arg_path" >&2
      exit 1
    fi
  elif [[ "$_arg_directory" != "." ]] && [[ ! -d "$_arg_directory" ]]; then
    echo "Error: Directory does not exist: $_arg_directory" >&2
    exit 1
  fi

  # Normalize extensions (remove leading dots)
  local normalized_exts=()
  for ext in "${_arg_ext[@]}"; do
    normalized_exts+=("${ext#.}")
  done
  _arg_ext=("${normalized_exts[@]}")
}

# ============================================================================
# EXPORT ARGUMENTS
# ============================================================================

export_arguments() {
  # Boolean flags
  export DRY_RUN="$_arg_dry_run"
  export VERBOSE="$_arg_verbose"
  export NO_THROTTLE="$_arg_no_throttle"
  export NO_CONFIRM="$_arg_no_confirm"
  export USE_PARALLEL="$([ "$_arg_no_parallel" = "on" ] && echo "false" || echo "true")"
  export SKIP_SAMPLING="$_arg_skip_sampling"

  # Single-value options
  export MAX_FILES="$_arg_max_files"
  export MAX_RATE="$_arg_max_rate"
  export MAX_MEMORY="$_arg_max_memory"
  export BATCH_SIZE="$_arg_batch_size"
  export WORKERS="$_arg_workers"
  export CHUNK_SIZE="$_arg_chunk_size"
  export SAMPLE_SIZE="$_arg_sample_size"
  export LOG_LEVEL="$_arg_log_level"

  # Optional single-value options
  if [[ -n "$_arg_log_file" ]]; then
    export LOG_FILE="$_arg_log_file"
  fi

  # Determine target directory (--path takes precedence)
  if [[ -n "$_arg_path" ]]; then
    export TARGET_DIR="$_arg_path"
  else
    export TARGET_DIR="$_arg_directory"
  fi

  # Extensions array
  if [[ ${#_arg_ext[@]} -gt 0 ]]; then
    export EXTENSIONS=("${_arg_ext[@]}")
  else
    # Will use DEFAULT_EXTENSIONS from main script
    export EXTENSIONS=()
  fi
}

# ============================================================================
# MAIN EXECUTION (when sourced by main script)
# ============================================================================

# Only execute parsing if this script is being sourced with arguments
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Being sourced - parse arguments
  parse_arguments "$@"
  validate_arguments
  export_arguments
fi
