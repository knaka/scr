#!/bin/sh

task_install() ( # Install in each directory.
  cd "$(dirname "$0")" || exit 1
  for dir in "$script_dir_path"/*
  do
    if test -d "$dir"
    then
      echo "Installing in $dir" >&2
      (cd "$dir" && sh ./task.sh install)
    fi
  done
)

task_client__build() ( # [args...] Build client.
  printf "Building client: "
  delim=""
  for arg in "$@"
  do
    printf "%s%s" "$delim" "$arg"
    delim=", "
  done
  echo
)

task_client__deploy() ( # [args...] Deploy client.
  printf "Deploying client: "
  delim=""
  for arg in "$@"
  do
    printf "%s%s" "$delim" "$arg"
    delim=", "
  done
  echo
)

task_task_cmd__copy() ( # Copy task.cmd to each directory.
  cd "$(dirname "$0")" || exit 1
  for dir in *
  do
    if ! test -d "$dir"
    then
      continue
    fi
    cp -f task.cmd "$dir"/task.cmd
  done
)

task_home_link() ( # Link this directory to home.
  script_dir_path="$(realpath "$(dirname "$0")")"
  script_dir_name="$(basename "$script_dir_path")"
  ln -sf "$script_dir_path" "$HOME"/"$script_dir_name"
)

subcmd_env() ( # Show environment.
  echo "APP_SENV:" "${APP_SENV:-}"
  echo "APP_ENV:" "${APP_ENV:-}"
)

# Mock for test of help.
delegate_tasks() (
  cd "$(dirname "$0")" || exit 1
  case "$1" in
    tasks)
      echo "exclient:build     Build client."
      echo "exclient:deploy    Deploy client."
      ;;
    subcmds)
      echo "exgit       Run git command."
      echo "exdocker    Run docker command."
      ;;
    extra:install)
      echo Installing extra commands...
      echo Done
      ;;
    *)
      echo "Unknown task: $1" >&2
      return 1
      ;;
  esac
)
