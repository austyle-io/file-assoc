#!/bin/bash
# m4_ignore(
echo "This is just a parsing library template, not the script  you are looking for."
exit 1
)m4_include([argbash.m4])

# ARG_OPTIONAL_BOOLEAN([dry-run], [d], [Show what would be changed without making changes])
# ARG_OPTIONAL_BOOLEAN([verbose], [v], [Show detailed output with progress])
# ARG_OPTIONAL_SINGLE([path], [p], [Target directory path (takes precedence over positional arg)], [])
# ARG_OPTIONAL_REPEATED([ext], [e], [File extension to process (can be used multiple times)], [])
# ARG_OPTIONAL_SINGLE([max-files], [], [Maximum files to process], [10000])
# ARG_OPTIONAL_SINGLE([max-rate], [], [Maximum files per second], [100])
# ARG_OPTIONAL_SINGLE([max-memory], [], [Maximum memory in MB], [500])
# ARG_OPTIONAL_SINGLE([batch-size], [], [Files per batch], [1000])
# ARG_OPTIONAL_BOOLEAN([no-throttle], [], [Disable all throttling (not recommended)])
# ARG_OPTIONAL_BOOLEAN([no-confirm], [], [Skip confirmation prompts])
# ARG_OPTIONAL_SINGLE([workers], [], [Number of parallel workers (0=auto)], [0])
# ARG_OPTIONAL_SINGLE([chunk-size], [], [Files per worker chunk], [100])
# ARG_OPTIONAL_BOOLEAN([no-parallel], [], [Disable parallel processing (sequential mode)])
# ARG_OPTIONAL_SINGLE([sample-size], [], [Number of files to sample before full scan], [100])
# ARG_OPTIONAL_BOOLEAN([skip-sampling], [], [Skip sampling phase and proceed directly to full scan])
# ARG_OPTIONAL_SINGLE([log-level], [], [Log level: DEBUG, INFO, WARN, ERROR], [INFO])
# ARG_OPTIONAL_SINGLE([log-file], [], [Custom log file location], [])
# ARG_POSITIONAL_SINGLE([directory], [Directory to process (default: current directory)], [.])
# ARG_DEFAULTS_POS
# ARG_HELP([Reset file associations for existing files by clearing LaunchServices extended attributes.\nThis forces files to use the system-wide defaults set by duti.\n\nEnhanced with comprehensive logging, resource limits, and throttling.])
# ARGBASH_SET_INDENT([  ])
# ARGBASH_GO

# [ <-- needed because of Argbash

# Script logic starts here

# Argument validation
validate_arguments() {
  # Validate max-files
  if ! [[ "$_arg_max_files" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --max-files must be a positive integer" >&2
    exit 1
  fi

  # Validate max-rate
  if ! [[ "$_arg_max_rate" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --max-rate must be a positive integer" >&2
    exit 1
  fi

  # Validate max-memory
  if ! [[ "$_arg_max_memory" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --max-memory must be a positive integer" >&2
    exit 1
  fi

  # Validate batch-size
  if ! [[ "$_arg_batch_size" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --batch-size must be a positive integer" >&2
    exit 1
  fi

  # Validate workers
  if ! [[ "$_arg_workers" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --workers must be a non-negative integer" >&2
    exit 1
  fi

  # Validate chunk-size
  if ! [[ "$_arg_chunk_size" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --chunk-size must be a positive integer" >&2
    exit 1
  fi

  # Validate sample-size
  if ! [[ "$_arg_sample_size" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "Error: --sample-size must be a positive integer" >&2
    exit 1
  fi

  # Validate log-level
  case "$_arg_log_level" in
    DEBUG|INFO|WARN|ERROR) ;;
    *)
      printf '%s\n' "Error: --log-level must be one of: DEBUG, INFO, WARN, ERROR" >&2
      exit 1
      ;;
  esac

  # Validate directory exists
  if [[ -n "$_arg_path" ]]; then
    if [[ ! -d "$_arg_path" ]]; then
      printf '%s\n' "Error: Path does not exist: $_arg_path" >&2
      exit 1
    fi
  elif [[ "$_arg_directory" != "." ]] && [[ ! -d "$_arg_directory" ]]; then
    printf '%s\n' "Error: Directory does not exist: $_arg_directory" >&2
    exit 1
  fi

  # Normalize extensions (remove leading dots)
  local normalized_exts=()
  for ext in "${_arg_ext[@]}"; do
    normalized_exts+=("${ext#.}")
  done
  _arg_ext=("${normalized_exts[@]}")
}

# Export parsed arguments for main script
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

  # Extensions array (convert to proper array format)
  if [[ ${#_arg_ext[@]} -gt 0 ]]; then
    export EXTENSIONS=("${_arg_ext[@]}")
  else
    # Will use DEFAULT_EXTENSIONS from main script
    export EXTENSIONS=()
  fi
}

# Validate arguments
validate_arguments

# Export for main script
export_arguments

# ] <-- needed because of Argbash
