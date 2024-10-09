#!/bin/sh
set -o nounset -o errexit

test "${guard_e249abe+set}" = set && return 0; guard_e249abe=x

. task.sh
. task-volta.lib.sh
. task-next.lib.sh

mkdir_sync_ignored .wrangler build

mkdir -p .wrangler
set_sync_ignored .wrangler

subcmd_esbuild() {
  set_node_env
  if type node_modules/esbuild/bin/esbuild 2> /dev/null > /dev/null
  then
    node_modules/esbuild/bin/esbuild "$@"
  else
    node node_modules/esbuild/bin/esbuild "$@"
  fi
}

# shellcheck disable=SC2120
task_worker__build() {
  subcmd_esbuild "$@" --bundle worker/index.ts --format=esm --outfile=public/_worker.js
}

subcmd_wrangler() {
  set_node_env
  node"$(exe_ext)" node_modules/wrangler/bin/wrangler.js "$@"
}

task_worker__dev() {
  load_env
  opt_9754aa0=
  if test "${NEXT_PUBLIC_API_PORT+set}" = set
  then
    opt_9754aa0="--port=$NEXT_PUBLIC_API_PORT"
  fi
  # shellcheck disable=SC2086
  subcmd_wrangler pages dev $opt_9754aa0 --live-reload --show-interactive-dev-session=false public/
}

task_worker__depbuild() {
  if ! newer worker/ --than public/_worker.js
  then
    return 0
  fi
  task_worker__build
}

task_worker__watchbuild() {
  # "forever" is used to keep the process running even after the stdin is closed.
  # task_worker__build --watch=forever
  subcmd_esbuild "$@" --bundle worker/index.ts --format=esm --outfile=public/_worker.js --watch=forever
  # set_node_env
  # node node_modules/esbuild/bin/esbuild --bundle worker/index.ts --format=esm --outfile=public/_worker.js --watch=forever
  # while true
  # do
  #   task_worker__depbuild
  #   sleep 1
  # done
}

task_next__build() {
  subcmd_next build "$@"
}

# shellcheck disable=SC2120
task_next__depbuild() {
  if ! newer app/ public/ --than build/out
  then
    return 0
  fi
  task_next__build "$@"
}

usage_next_prompt() {
  echo
  echo "[b] Open a Browser"
  echo "[c] Clear console"
  echo "[x] to exit"
}

next_prompt() {
  usage_next_prompt
  while true
  do
    case "$(get_key)" in
      b) open_browser "$1" ;;
      c) clear ;;
      x) break ;;
      *) usage_next_prompt ;;
    esac
  done
}

task_next__dev() {
  load_env
  opts_93039d0=
  if test "${NEXT_DEV_SERVER_PORT+set}" = set
  then
    opts_93039d0="--port=$NEXT_DEV_SERVER_PORT"
  fi
  set_node_env
  # shellcheck disable=SC2086
  subcmd_next dev $opts_93039d0
}

task_dev() {
  NODE_ENV=development
  export NODE_ENV
  APP_ENV=development
  export APP_ENV
  sh task.sh worker:watchbuild &
  sh task.sh worker:dev &
  sh task.sh next:dev 2>&1 | tee "$(temp_dir_path)"/next-dev.log &
  while true
  do
    sleep 1
    if grep -q "Ready in " "$(temp_dir_path)"/next-dev.log > /dev/null 2>&1
    then
      break
    fi
  done
  load_env
  next_prompt "http://localhost:${NEXT_DEV_SERVER_PORT:-3000}"
}

task_pages__start() {
  subcmd_wrangler pages dev build/out/
}

task_start() {
  NODE_ENV=production
  export NODE_ENV
  APP_ENV=production
  export APP_ENV
  sh task.sh worker:build
  # "EBUSY" error occurs on Windows frequently.
  if is_windows
  then
    for _ in 1 2 3
    do
      rm -fr .next/* > /dev/null 2>&1 || :
      sleep 1
    done
    rm -fr .next/*
  fi
  sh task.sh next:build
  # Wrangler provides interactive CUI.
  sh task.sh pages:start
}
