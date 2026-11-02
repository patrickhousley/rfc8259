#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/module"

  # Modules are cloned and downloaded relative to the project root
  PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
  MODULE_PATH="${MODULES_ROOT}/dep"
  mkdir -p "${PROJECT_ROOT}/modules"

  stub_command "git"
  stub_command "tar"
  PATH="${STUB_BIN}:${PATH}"
}

# _module_git_clone

@test "_module_git_clone requires a name" {
  run _module_git_clone --clone-uri=uri --ref=main

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "--name is a required parameter"
}

@test "_module_git_clone requires a clone uri" {
  run _module_git_clone --name=dep --ref=main

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "--clone-uri is a required parameter"
}

@test "_module_git_clone requires a ref" {
  run _module_git_clone --name=dep --clone-uri=uri

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "--ref is a required parameter"
}

@test "_module_git_clone fails on unknown argument" {
  run _module_git_clone --bogus

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "Unknown argument [--bogus]"
}

@test "_module_git_clone accepts arguments in any case" {
  run _module_git_clone --NAME=dep --CLONE-URI=uri --REF=main

  assert_success
}

@test "_module_git_clone accepts space separated arguments" {
  run _module_git_clone --name dep --clone-uri uri --ref main

  assert_success
}

@test "_module_git_clone clones a missing module then checks out the ref" {
  run _module_git_clone --name=dep --clone-uri=https://example.test/dep.git --ref=v1

  assert_success
  run stub_calls git
  assert_output - <<EOF
clone --quiet https://example.test/dep.git ${MODULE_PATH}
-C ${MODULE_PATH} reset --quiet --hard
-C ${MODULE_PATH} clean --quiet -xfd
-C ${MODULE_PATH} checkout --quiet v1
-C ${MODULE_PATH} pull --quiet
EOF
}

@test "_module_git_clone does not clone an existing module" {
  mkdir -p "${MODULE_PATH}/.git"

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  assert_success
  run stub_calls git
  refute_output --partial "clone --quiet uri"
  assert_line "-C ${MODULE_PATH} checkout --quiet v1"
}

@test "_module_git_clone replaces a module directory that is not a git checkout" {
  mkdir -p "${MODULE_PATH}"
  touch "${MODULE_PATH}/stale"

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  assert_success
  [[ ! -e "${MODULE_PATH}/stale" ]]
}

@test "_module_git_clone fails when the clone fails" {
  # shellcheck disable=SC2016
  stub_command "git" '[[ "$1" == clone ]] && exit 1; exit 0'

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "Git clone failed"
  assert_equal "$(stub_calls git | wc -l)" "1"
}

@test "_module_git_clone fails when the final refresh step fails" {
  mkdir -p "${MODULE_PATH}/.git"
  # shellcheck disable=SC2016
  stub_command "git" '[[ "$3" == pull ]] && exit 1; exit 0'

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "Git checkout/refresh failed"
}

@test "_module_git_clone fails when an earlier refresh step fails" {
  mkdir -p "${MODULE_PATH}/.git"
  # shellcheck disable=SC2016
  stub_command "git" '[[ "$3" == checkout ]] && exit 1; exit 0'

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  assert_failure
  assert_log --scope "_module_git_clone" --level "fatal" "Git checkout/refresh failed"
}

@test "_module_git_clone logs with its own scope when verbose" {
  LOG_VERBOSE=0
  mkdir -p "${MODULE_PATH}/.git"

  run _module_git_clone --name=dep --clone-uri=uri --ref=v1

  refute_log --scope "_fetch_download" --partial ""
  refute_log --scope "_module_download" --partial ""
}

# _module_download

# Replaces the fetch helper so downloads are recorded instead of performed
_stub_fetch() {
  # shellcheck disable=SC2329
  _fetch_download() {
    echo "fetch [$*]" >>"${BATS_TEST_TMPDIR}/fetches"
  }
}

@test "_module_download requires a name" {
  run _module_download --download-url=https://example.test/dep.zip

  assert_failure
  assert_log --scope "_module_download" --level "fatal" "--name is a required parameter"
}

@test "_module_download requires a download url" {
  run _module_download --name=dep

  assert_failure
  assert_log --scope "_module_download" --level "fatal" "--download-url is a required parameter"
}

@test "_module_download fails on unknown argument" {
  run _module_download --bogus

  assert_failure
  assert_log --scope "_module_download" --level "fatal" "Unknown argument [--bogus]"
}

@test "_module_download rejects a non numeric strip-components" {
  local value
  for value in abc -1 1.5 1a; do
    run _module_download --name=dep --download-url=https://example.test/dep.zip --strip-components="${value}"

    assert_failure
    assert_log --scope "_module_download" --level "fatal" "--strip-components must be a number >=0"
  done
}

@test "_module_download accepts space separated arguments" {
  _stub_fetch

  run _module_download --name dep --download-url https://example.test/dep.tar.gz --sha256 abc --strip-components 2 --tar

  assert_success
  run cat "${BATS_TEST_TMPDIR}/fetches"
  assert_output --partial "--sha256=abc"
  assert_equal "$(stub_calls tar)" "-xf ${MODULE_PATH}/dep.tar.gz --strip-components=2 -C ${MODULE_PATH}"
}

@test "_module_download fetches the url into the module directory with caching" {
  _stub_fetch

  run _module_download --name=dep --download-url=https://example.test/path/dep.bin --sha256=abc123

  assert_success
  run cat "${BATS_TEST_TMPDIR}/fetches"
  assert_output "fetch [--url=https://example.test/path/dep.bin --out-file=${MODULE_PATH}/dep.bin --sha256=abc123 --cache]"
}

@test "_module_download passes an empty hash when none is given" {
  _stub_fetch

  run _module_download --name=dep --download-url=https://example.test/dep.bin

  assert_success
  run cat "${BATS_TEST_TMPDIR}/fetches"
  assert_output --partial "--sha256= "
}

@test "_module_download does not extract by default" {
  _stub_fetch

  run _module_download --name=dep --download-url=https://example.test/dep.bin

  assert_success
  assert_equal "$(stub_calls tar)" ""
}

@test "_module_download extracts the archive with --tar" {
  _stub_fetch

  run _module_download --name=dep --download-url=https://example.test/dep.tar.gz --tar

  assert_success
  assert_equal "$(stub_calls tar)" "-xf ${MODULE_PATH}/dep.tar.gz --strip-components=1 -C ${MODULE_PATH}"
}

@test "_module_download passes strip-components to tar" {
  _stub_fetch

  run _module_download --name=dep --download-url=https://example.test/dep.tar.gz --tar --strip-components=0

  assert_success
  assert_equal "$(stub_calls tar)" "-xf ${MODULE_PATH}/dep.tar.gz --strip-components=0 -C ${MODULE_PATH}"
}

@test "_module_download does not extract when the fetch fails" {
  # shellcheck disable=SC2329
  _fetch_download() {
    _log "_fetch_download" "Curl failed" "fatal"
  }

  run _module_download --name=dep --download-url=https://example.test/dep.tar.gz --tar

  assert_failure
  assert_equal "$(stub_calls tar)" ""
}
