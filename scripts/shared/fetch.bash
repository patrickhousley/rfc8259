#!/usr/bin/env bash
set -euo pipefail

# Prints the value of a header from the final response in a curl dump-header file
#
# curl writes one header block per redirect hop, only the last block is relevant
_fetch_header_value() {
  local headers_file="${1}"
  local name="${2,,}"

  awk -v name="${name}" '
    /^HTTP\// { value = "" }
    {
      line = $0
      sub(/\r$/, "", line)
      key = tolower(substr(line, 1, length(name) + 1))
      if (key == name ":") {
        value = substr(line, length(name) + 2)
        sub(/^[ \t]+/, "", value)
      }
    }
    END { print value }
  ' "${headers_file}"
}

_fetch_download() {
  local url
  local out_file
  local cache=0
  local no_cache=0
  local headers_file
  local sha256

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --url)
      url="${2}"
      shift 2
      ;;
    --url=*)
      url="${1#*=}"
      shift 1
      ;;
    --out-file)
      out_file="${2}"
      shift 2
      ;;
    --out-file=*)
      out_file="${1#*=}"
      shift 1
      ;;
    --cache)
      cache=1
      shift 1
      ;;
    --headers-file)
      headers_file="${2}"
      shift 2
      ;;
    --headers-file=*)
      headers_file="${1#*=}"
      shift 1
      ;;
    --no-cache)
      no_cache=1
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
    *)
      _log "_fetch_download" "Unknown command argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ $no_cache -eq 1 ]]; then
    _log "_fetch_download" "Disabling download cache" "verbose"
    cache=0
  fi

  if [[ $cache -eq 1 && -z "${headers_file:-}" ]]; then
    headers_file="${out_file}.headers"
    _log "_fetch_download" "Defaulting headers output file to ${headers_file}" "verbose"
  fi

  if [[ -z "${url:-}" ]]; then
    _log "_fetch_download" "--url is a required parameter" "fatal"
  fi
  if [[ -z "${out_file:-}" ]]; then
    _log "_fetch_download" "--out-file is a required parameter" "fatal"
  else
    mkdir -p "$(dirname "${out_file}")"
  fi
  if [[ -n "${headers_file:-}" ]]; then
    mkdir -p "$(dirname "${headers_file}")"
  fi

  local cache_args=()
  if [[ $cache -eq 1 && -n "${headers_file:-}" && -f "${headers_file:-}" ]]; then
    _log "_fetch_download" "Reading cache headers from ${headers_file}" "verbose"
    local etag
    local last_mod
    etag=$(_fetch_header_value "$headers_file" "etag")
    last_mod=$(_fetch_header_value "$headers_file" "last-modified")

    if [[ -n "$etag" ]]; then
      cache_args+=("-H" "If-None-Match: $etag")
    fi
    if [[ -n "$last_mod" ]]; then
      cache_args+=("-H" "If-Modified-Since: $last_mod")
    fi
  fi

  _log "_fetch_download" "Starting download for:" "verbose"
  _log "_fetch_download" "  url: ${url}" "verbose"
  _log "_fetch_download" "  out_file: ${out_file}" "verbose"
  _log "_fetch_download" "  cache: ${cache}" "verbose"
  _log "_fetch_download" "  no_cache: ${no_cache}" "verbose"
  _log "_fetch_download" "  headers_file: ${headers_file:-}" "verbose"
  _log "_fetch_download" "  sha256: ${sha256:-}" "verbose"
  _log "_fetch_download" "  cache_enabled: $([[ $cache -eq 1 ]] && printf "true" || printf "false")" "verbose"
  _log "_fetch_download" "  cache_args: ${cache_args[*]}" "verbose"

  local tmp_out_file
  local tmp_headers_file
  local http_code
  local curl_status=0

  tmp_out_file="$(mktemp)"
  tmp_headers_file="$(mktemp)"
  http_code=$(curl --silent \
    --connect-timeout 5 \
    --max-time 15 \
    -L \
    --fail-with-body \
    "${cache_args[@]}" \
    -o "$tmp_out_file" \
    -D "$tmp_headers_file" \
    -w "%{http_code}" \
    "$url") || curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    rm -f "$tmp_out_file" "$tmp_headers_file"
    _log "_fetch_download" "Curl failed with exit code ${curl_status} (URL: ${url})" "fatal"
  elif [[ $http_code -eq 304 ]]; then
    rm -f "$tmp_out_file" "$tmp_headers_file"
    _log "_fetch_download" "Cache Hit (304) for URL: ${url}" "verbose"
  elif [[ $http_code -eq 200 ]]; then
    _log "_fetch_download" "Downloaded for URL: ${url}" "verbose"

    if [[ -n "${sha256:-}" ]]; then
      local download_file_hash
      download_file_hash="$(sha256sum """${tmp_out_file}""" | awk '{print $1}')"
      if [[ "${download_file_hash}" != "${sha256}" ]]; then
        rm -f "$tmp_out_file" "$tmp_headers_file"
        _log "_fetch_download" "Downloaded file failed hash check" "fatal"
      fi
    fi

    mv "${tmp_out_file}" "${out_file}" || true

    if [[ -n "${headers_file:-}" ]]; then
      mv "${tmp_headers_file}" "${headers_file}" || true
    fi
    rm -f "$tmp_out_file" "$tmp_headers_file"
  else
    rm -f "$tmp_out_file" "$tmp_headers_file"
    _log "_fetch_download" "Fetch failed with network status code ${http_code}" "fatal"
  fi

  return $curl_status
}
