#!/usr/bin/env bash
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

usage() { 
  echo "Usage:" && echo "  $(basename "$0") COMMIT_MSG KEYWORDS DETECT_TYPE PROJ_PATH" && echo "  KEYWORDS: (Space seperated string); DETECT_TYPE: build or deploy"; 
  echo "  ENV: [BUILD_COMMIT_DETECTOR_STRICTNESS: default low, can also be moderate or high (ACTION PROVIDED)], [RUNNER_DEBUG: default false (GITHUB PROVIDED)]"
}

detect_build_necessity() {
  local commit_msg=$1
  local keywords_str=$2
  local detect_type=$3
  local proj_path=$4
  local keywords
  local detect_type="${detect_type,,}"
  IFS=' ' read -r -a keywords <<< "$keywords_str"

  if type -p ggrep > /dev/null; then grep=ggrep; else grep="grep"; fi
  if $grep --version | grep -w 'BSD' > /dev/null; then log_err "GNU grep is required; Install with 'brew install grep'" && exit 1; fi

  if [[ "$detect_type" != "build" ]] && [[ "$detect_type" != "deploy" ]]; then
    log_err "Invalid detect_type: ${detect_type}; Valid options: build, deploy" && exit 1
  fi
  pushd "$proj_path" > /dev/null
    if [[ "$commit_msg" == '--' ]] || [[ "$commit_msg" == ' ' ]]; then
      log_warning "commit_msg: is not set; using '$(git log --format=%B -n 1 HEAD)'"
      commit_msg="$(git log --format=%B -n 1 HEAD)"
    fi
  popd > /dev/null

  log_info "keywords: ${keywords[*]}"
  for keyword in "${keywords[@]}"; do
    if $grep -wP "(?<![\w-])$keyword(?![\w-])" <<< "$commit_msg"; then
      echo "build_necessary=$(build_necessity_json_output "$detect_type" false)" | tee -a "${GITHUB_ENV:-/dev/null}" "${GITHUB_OUTPUT:-/dev/null}"
      case ${BUILD_COMMIT_DETECTOR_STRICTNESS:-low} in
        low) return 0 ;;
        moderate) log_warning "BUILD_COMMIT_DETECTOR_STRICTNESS is set to moderate.." && return 1 ;;
        high) log_err "BUILD_COMMIT_DETECTOR_STRICTNESS is set to high... Exiting..." && exit 1 ;;
      esac
    fi
  done
  echo "build_necessary=$(build_necessity_json_output "$detect_type" true)" | tee -a "${GITHUB_ENV:-/dev/null}" "${GITHUB_OUTPUT:-/dev/null}"
}

if "${RUNNER_DEBUG:-false}"; then set -x; fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail 
  if (( $# !=4 )); then usage && exit 1; fi
   detect_build_necessity "$@";
fi
