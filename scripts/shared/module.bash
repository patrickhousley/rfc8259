#!/usr/bin/env bash
set -euo pipefail

_module_git_clone() {
  local module_name
  local module_clone_uri
  local module_ref

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --name)
      module_name="${2}"
      shift 2
      ;;
    --name=*)
      module_name="${1#*=}"
      shift 1
      ;;
    --clone-uri)
      module_clone_uri="${2}"
      shift 2
      ;;
    --clone-uri=*)
      module_clone_uri="${1#*=}"
      shift 1
      ;;
    --ref)
      module_ref="${2}"
      shift 2
      ;;
    --ref=*)
      module_ref="${1#*=}"
      shift 1
      ;;
    *)
      _log "_module_git_clone" "Unknown command argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${module_name:-}" ]]; then
    _log "_module_git_clone" "--name is a required parameter" "fatal"
  fi
  if [[ -z "${module_clone_uri:-}" ]]; then
    _log "_module_git_clone" "--clone-uri is a required parameter" "fatal"
  fi
  if [[ -z "${module_ref:-}" ]]; then
    _log "_module_git_clone" "--ref is a required parameter" "fatal"
  fi

  local module_path
  module_path="${MODULES_ROOT}/${module_name}"

  _log "_module_git_clone" "Starting module clone for:" "verbose"
  _log "_module_git_clone" "  module_name: ${module_name}" "verbose"
  _log "_module_git_clone" "  module_clone_uri: ${module_clone_uri}" "verbose"
  _log "_module_git_clone" "  module_ref: ${module_ref}" "verbose"
  _log "_module_git_clone" "  module_path: ${module_path}" "verbose"

  local exit_code=0
  if [[ ! -d "${module_path}/.git" ]]; then
    rm -rf "${module_path}"

    git clone --quiet "${module_clone_uri}" "${module_path}" || exit_code=1

    if [[ $exit_code -ne 0 ]]; then
      _log "_module_git_clone" "Git clone failed" "fatal"
    fi
  fi

  git -C "${module_path}" reset --quiet --hard &&
    git -C "${module_path}" clean --quiet -xfd &&
    git -C "${module_path}" checkout --quiet "${module_ref}" &&
    git -C "${module_path}" pull --quiet ||
    exit_code=1

  if [[ $exit_code -ne 0 ]]; then
    _log "_module_git_clone" "Git checkout/refresh failed" "fatal"
  else
    _log "_module_git_clone" "Git module clone complete" "verbose"
  fi
}

_module_download() {
  local module_name
  local module_download_url
  local module_strip_components
  local sha256
  local run_tar=0

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --name)
      module_name="${2}"
      shift 2
      ;;
    --name=*)
      module_name="${1#*=}"
      shift 1
      ;;
    --download-url)
      module_download_url="${2}"
      shift 2
      ;;
    --download-url=*)
      module_download_url="${1#*=}"
      shift 1
      ;;
    --strip-components)
      module_strip_components="${2}"
      shift 2
      ;;
    --strip-components=*)
      module_strip_components="${1#*=}"
      shift 1
      ;;
    --sha256)
      sha256="${2}"
      shift 2
      ;;
    --sha256=*)
      sha256="${1#*=}"
      shift 1
      ;;
    --tar)
      run_tar=1
      shift 1
      ;;
    *)
      _log "_module_download" "Unknown command argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${module_name:-}" ]]; then
    _log "_module_download" "--name is a required parameter" "fatal"
  fi
  if [[ -z "${module_download_url:-}" ]]; then
    _log "_module_download" "--download-url is a required parameter" "fatal"
  fi
  if [[ -z "${module_strip_components:-}" ]]; then
    module_strip_components=1
  elif [[ "${module_strip_components}" =~ [^0-9] ]]; then
    _log "_module_download" "--strip-components must be a number >=0" "fatal"
  fi

  local module_path
  local download_file_path
  module_path="${MODULES_ROOT}/${module_name}"
  download_file_path="${module_path}/$(basename "$module_download_url")"

  _log "_module_download" "Starting module download for:" "verbose"
  _log "_module_download" "  module_name: ${module_name}" "verbose"
  _log "_module_download" "  module_download_url: ${module_download_url}" "verbose"
  _log "_module_download" "  module_strip_components: ${module_strip_components}" "verbose"
  _log "_module_download" "  module_path: ${module_path}" "verbose"
  _log "_module_download" "  download_file_path: ${download_file_path}" "verbose"

  _fetch_download \
    --url="${module_download_url}" \
    --out-file="${download_file_path}" \
    --sha256="${sha256:-}" \
    --cache

  if [[ $run_tar -eq 1 ]]; then
    _log "_module_download" "Extracting module" "verbose"
    tar -xf "${download_file_path}" --strip-components="${module_strip_components}" -C "${module_path}"
  fi

  _log "_module_download" "Download complete" "verbose"
}
