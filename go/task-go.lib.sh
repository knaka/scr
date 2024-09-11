#!/bin/sh

# All releases - The Go Programming Language https://go.dev/dl/
ver=1.23.0

is_windows() {
  test "$(uname -s)" = "Windows_NT" && return 0 || return 1
}

# gobin returns the path to the Go bin directory.
gobin() {
  if test "${GOBIN+SET}" = "SET"
  then
    echo "$GOBIN"
    return
  fi
  if test "${GOROOT+SET}" = "SET"
  then
    echo "$GOROOT"/bin
    return
  fi
  if test "${GOPATH+SET}" = "SET"
  then
    echo "$GOPATH"/bin
    return
  fi
  if which go > /dev/null 2>&1
  then
    echo "$(go env GOROOT)"/bin
    return
  fi
  for dir_path in \
    "$HOME"/sdk/go${ver} \
    /usr/local/go \
    /usr/local/Cellar/go/* \
    "/Program Files"/Go \
    "$HOME"/go
  do
    if type "$dir_path"/bin/go > /dev/null 2>&1
    then
      echo "$dir_path"/bin
      return
    fi
  done
  _sdk_dir_path="$HOME"/sdk
  _goroot="$_sdk_dir_path"/go${ver}
  case "$(uname -s)" in
    Linux) _goos=linux;;
    Darwin) _goos=darwin;;
    Windows_NT) _goos=windows;;
    *) exit 1;;
  esac
  case "$(uname -m)" in
    arm64) _goarch=arm64;;
    x86_64) _goarch=amd64;;
    *) exit 1;;
  esac
  mkdir -p "$_sdk_dir_path"
  if is_windows
  then
    _temp_dir_path=$(mktemp -d)
    zip_path="$_temp_dir_path"/temp.zip
    curl --location -o "$zip_path" "https://go.dev/dl/go$ver.$_goos-$_goarch.zip"
    (cd "$_sdk_dir_path" || exit 1; unzip -q "$zip_path" >&2)
    rm -fr "$_temp_dir_path"
  else
    curl --location -o - "https://go.dev/dl/go$ver.$_goos-$_goarch.tar.gz" | (cd "$_sdk_dir_path" || exit 1; tar -xzf -)
  fi
  mv "$_sdk_dir_path"/go "$_goroot"
  echo "$_goroot"/bin
}

go_cmd_result=""

go_cmd() {
  if test -n "$go_cmd_result"
  then
    echo "$go_cmd_result"
    return
  fi
  go_cmd_result="$(gobin)"/go
  echo "$go_cmd_result"
}

subcmd_go() { # Run go command.
  exec "$(go_cmd)" "$@"
}

subcmd_build() { # Build Go source files incrementally.
  cd "$(dirname "$0")" || exit 1
  go_bin_dir_path="$HOME"/go-bin/.bin
  mkdir -p "$go_bin_dir_path"
  name="$1"
  shift
  ext=
  if is_windows
  then
    ext=.exe
  fi
  target_bin_path="$go_bin_dir_path"/"$name$ext"
  if ! test -x "$target_bin_path" || test -n "$(find "$name.go" -newer "$target_bin_path"  2>/dev/null)"
  then
    # echo building >&2
    "$(go_cmd)" build -o "$target_bin_path" "$name.go"
  fi
}

task_install() { # Install Go tools.
  cd "$(dirname "$0")" || exit 1
  go_sim_dir_path="$HOME"/go-bin
  mkdir -p "$go_sim_dir_path"
  rm -f "$go_sim_dir_path"/*
  for go_file in *.go
  do
    if ! test -r "$go_file"
    then
      continue
    fi
    name=$(basename "$go_file" .go)
    target_sim_path="$go_sim_dir_path"/"$name"
    if is_windows
    then
      pwd_backslash=$(echo "$PWD" | sed 's|/|\\|g')
      go_sim_dir_path_backslash=$(echo "$go_sim_dir_path" | sed 's|/|\\|g')
      cat <<EOF > "$target_sim_path".cmd
@echo off
call $pwd_backslash\task build $name
$go_sim_dir_path_backslash\.bin\\$name.exe %*
EOF
    else
      cat <<EOF > "$target_sim_path"
#!/bin/sh
$PWD/task build "$name"
exec "$go_sim_dir_path"/.bin/"$name" "\$@"
EOF
      chmod +x "$target_sim_path"
    fi
  done
}

task_install_bin() {
  gopath="$HOME"/go
  bin_dir_path="$gopath"/bin
  mkdir -p "$bin_dir_path"
  repos_dir_path="$HOME"/repos
  mkdir -p "$repos_dir_path"
  exe_ext=
  if is_windows
  then
    exe_ext=.exe
  fi
  # shellcheck disable=SC2043
  for repo_path in \
    "https://github.com/knaka/peco.git cmd/peco"
  do
    repo=${repo_path%% *}
    path=${repo_path#* }
    cmd_name="$(basename "$path")"
    if test -z "$cmd_name"
    then
      cmd_name=$(basename "$repo" .git)
    fi
    if type "$bin_dir_path"/"$cmd_name" > /dev/null 2>&1
    then
      continue
    fi
    # repo_dir_path="$repos_dir_path"/
    repo_dir_name="$repo"
    repo_dir_name=${repo_dir_name%%.git}
    repo_dir_name=${repo_dir_name##https://}
    repo_dir_path="$repos_dir_path"/"$repo_dir_name"
    if ! test -d "$repo_dir_path"
    then
      "$(go_cmd)" run ./go-git-clone.go "$repo" "$repo_dir_path"
    fi
    (
      cd "$repo_dir_path" || exit 1
      "$(go_cmd)" build -o "$bin_dir_path"/"$cmd_name$exe_ext" ./"$path"
    )
  done
}

# shellcheck disable=SC1091
. "$(dirname "$0")"/attributes.lib.sh

for path in .idea .git
do
  # echo "debug2:" "$path" >&2
  if test -d "$(dirname "$0")"/"$path"
  then
    # echo "debug1:" "$path" >&2
    set_path_sync_ignored "$(dirname "$0")"/"$path"
  fi
done
