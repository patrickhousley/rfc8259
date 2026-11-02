#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"

  OUT_FILE="${BATS_TEST_TMPDIR}/downloads/out.bin"
  HEADERS_FILE="${BATS_TEST_TMPDIR}/downloads/out.headers.default"
  URL="https://example.test/out.bin"
  BODY="payload"
  BODY_SHA256="$(printf '%s' "${BODY}" | sha256sum | awk '{print $1}')"

  # The stub curl writes the response described by these variables to the -o and -D files
  export CURL_CODE=200
  export CURL_BODY="${BODY}"
  export CURL_HEADERS=$'HTTP/1.1 200 OK\r\nETag: "abc"\r\nLast-Modified: Mon, 01 Jan 2024 00:00:00 GMT\r\n'
  export CURL_EXIT=0
  _stub_curl
  PATH="${STUB_BIN}:${PATH}"
}

_stub_curl() {
  stub_command "curl" "$(
    cat <<'EOF'
out=""
headers=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  -o)
    out="$2"
    shift 2
    ;;
  -D)
    headers="$2"
    shift 2
    ;;
  *) shift 1 ;;
  esac
done
printf '%s' "${CURL_BODY}" >"${out}"
printf '%s' "${CURL_HEADERS}" >"${headers}"
printf '%s' "${CURL_CODE}"
exit "${CURL_EXIT}"
EOF
  )"
}

# Runs a download with the default url and output file plus any extra arguments
#
# A headers file is always given because a successful download aborts on an unset
# headers_file otherwise, see the known issue below
_download() {
  run _fetch_download --url="${URL}" --out-file="${OUT_FILE}" --sha256="" --headers-file="${HEADERS_FILE}" "$@"
}

@test "_fetch_download requires a url" {
  run _fetch_download --out-file="${OUT_FILE}" --sha256=""

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "--url is a required parameter"
  assert_equal "$(stub_calls curl)" ""
}

@test "_fetch_download requires an out file" {
  run _fetch_download --url="${URL}" --sha256=""

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "--out-file is a required parameter"
  assert_equal "$(stub_calls curl)" ""
}

@test "_fetch_download fails on unknown argument" {
  run _fetch_download --bogus

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "Unknown argument [--bogus]"
}

@test "_fetch_download accepts arguments in any case" {
  run _fetch_download --URL="${URL}" --OUT-FILE="${OUT_FILE}" --SHA256="" --HEADERS-FILE="${HEADERS_FILE}"

  assert_success
  [[ -f "${OUT_FILE}" ]]
}

@test "_fetch_download accepts space separated arguments" {
  run _fetch_download --url "${URL}" --out-file "${OUT_FILE}" --sha256 "" --headers-file "${HEADERS_FILE}"

  assert_success
}

@test "_fetch_download works without a headers file or caching" {
  run _fetch_download --url="${URL}" --out-file="${OUT_FILE}" --sha256=""

  assert_success
  assert_equal "$(cat "${OUT_FILE}")" "${BODY}"
}

@test "_fetch_download works without a sha256" {
  run _fetch_download --url="${URL}" --out-file="${OUT_FILE}" --headers-file="${HEADERS_FILE}"

  assert_success
  assert_equal "$(cat "${OUT_FILE}")" "${BODY}"
}

@test "_fetch_download writes the response to the out file" {
  _download

  assert_success
  assert_equal "$(cat "${OUT_FILE}")" "${BODY}"
}

@test "_fetch_download creates the parent directories" {
  local nested="${BATS_TEST_TMPDIR}/a/b/c/out.bin"

  _download --out-file="${nested}"

  assert_success
  [[ -f "${nested}" ]]
}

@test "_fetch_download requests the url with timeouts and failure on http errors" {
  _download

  assert_success
  run stub_calls curl
  assert_output --partial "--silent"
  assert_output --partial "--connect-timeout 5"
  assert_output --partial "--max-time 15"
  assert_output --partial " -L "
  assert_output --partial "--fail-with-body"
  assert_output --regexp " ${URL}\$"
}

@test "_fetch_download accepts a matching sha256" {
  _download --sha256="${BODY_SHA256}"

  assert_success
  assert_equal "$(cat "${OUT_FILE}")" "${BODY}"
}

@test "_fetch_download rejects a mismatched sha256 and keeps no file" {
  _download --sha256="0000"

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "Downloaded file failed hash check"
  [[ ! -e "${OUT_FILE}" ]]
}

@test "_fetch_download fails when curl fails" {
  CURL_EXIT=22

  _download

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "Curl failed with exit code 22 (URL: ${URL})"
  [[ ! -e "${OUT_FILE}" ]]
}

@test "_fetch_download fails on a successful status other than 200" {
  CURL_CODE=204

  _download

  assert_failure
  assert_log --scope "_fetch_download" --level "fatal" "Fetch failed with network status code 204"
  [[ ! -e "${OUT_FILE}" ]]
}

@test "_fetch_download keeps the existing file on a 304" {
  mkdir -p "$(dirname "${OUT_FILE}")"
  echo "old" >"${OUT_FILE}"
  CURL_CODE=304
  CURL_BODY=""

  _download --cache

  assert_success
  assert_equal "$(cat "${OUT_FILE}")" "old"
}

@test "_fetch_download saves headers next to the out file when caching" {
  run _fetch_download --url="${URL}" --out-file="${OUT_FILE}" --sha256="" --cache

  assert_success
  assert_equal "$(cat "${OUT_FILE}.headers")" "${CURL_HEADERS%$'\n'}"
}

@test "_fetch_download saves headers to a custom headers file" {
  local headers_file="${BATS_TEST_TMPDIR}/headers/custom"

  _download --cache --headers-file="${headers_file}"

  assert_success
  assert_equal "$(cat "${headers_file}")" "${CURL_HEADERS%$'\n'}"
  [[ ! -e "${OUT_FILE}.headers" ]]
}

@test "_fetch_download sends conditional headers from saved cache headers" {
  _download --cache --headers-file="${HEADERS_FILE}"
  rm "${STUB_BIN}/curl.calls"

  _download --cache --headers-file="${HEADERS_FILE}"

  assert_success
  run stub_calls curl
  assert_output --partial '-H If-None-Match: "abc"'
  assert_output --partial "-H If-Modified-Since: Mon, 01 Jan 2024 00:00:00 GMT"
}

@test "_fetch_download sends no conditional headers on the first cached download" {
  _download --cache

  assert_success
  run stub_calls curl
  refute_output --partial "If-None-Match"
  refute_output --partial "If-Modified-Since"
}

@test "_fetch_download ignores saved headers with --no-cache" {
  _download --cache
  rm "${STUB_BIN}/curl.calls"

  _download --cache --no-cache

  assert_success
  run stub_calls curl
  refute_output --partial "If-None-Match"
}

@test "_fetch_download does not default a headers file with --no-cache" {
  run _fetch_download --url="${URL}" --out-file="${OUT_FILE}" --sha256="" --cache --no-cache --headers-file="${HEADERS_FILE}"

  assert_success
  [[ ! -e "${OUT_FILE}.headers" ]]
}

@test "_fetch_download handles saved headers without an etag" {
  mkdir -p "$(dirname "${HEADERS_FILE}")"
  printf 'HTTP/1.1 200 OK\r\n' >"${HEADERS_FILE}"

  # bats disables errexit inside run so the real script behaviour needs its own shell
  # It runs from a file instead of bash -c because kcov reads BASH_SOURCE, which is unset in a -c string
  cat >"${BATS_TEST_TMPDIR}/download.bash" <<'EOF'
source "$1/shared/color.bash"
source "$1/shared/log.bash"
source "$1/shared/fetch.bash"
_fetch_download --url="$2" --out-file="$3" --sha256="" --cache --headers-file="$4"
EOF
  run bash -euo pipefail "${BATS_TEST_TMPDIR}/download.bash" "${SCRIPTS_ROOT}" "${URL}" "${OUT_FILE}" "${HEADERS_FILE}"

  assert_success
  assert_equal "$(stub_calls curl | wc -l)" "1"
}

@test "_fetch_download handles saved headers from redirected downloads" {
  mkdir -p "$(dirname "${OUT_FILE}")"
  printf 'HTTP/1.1 302 Found\r\nETag: "one"\r\n\r\nHTTP/1.1 200 OK\r\nETag: "two"\r\n' >"${HEADERS_FILE}"

  _download --cache

  run stub_calls curl
  assert_output --partial '-H If-None-Match: "two"'
}

@test "_fetch_download logs the download settings when verbose" {
  LOG_VERBOSE=0

  _download

  assert_log --scope "_fetch_download" --level "verbose" "Starting download for:"
  assert_log --scope "_fetch_download" --level "verbose" "  url: ${URL}"
  assert_log --scope "_fetch_download" --level "verbose" "Downloaded for URL: ${URL}"
}

@test "_fetch_download removes its temporary files" {
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "${TMPDIR}"
  CURL_CODE=304

  _download --cache

  assert_success
  assert_equal "$(find "${TMPDIR}" -type f)" ""
}

@test "_fetch_append_query starts the query string" {
  run _fetch_append_query "https://example.test/items" "limit" "20"

  assert_success
  assert_output "https://example.test/items?limit=20"
}

@test "_fetch_append_query extends an existing query string" {
  run _fetch_append_query "https://example.test/items?limit=20" "offset" "40"

  assert_success
  assert_output "https://example.test/items?limit=20&offset=40"
}

@test "_fetch_append_query defaults to an empty value" {
  run _fetch_append_query "https://example.test/items" "limit"

  assert_success
  assert_output "https://example.test/items?limit="
}
