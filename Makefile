# Makefile for the apt-repo install-page generator.
#
# Targets:
#   make all      = update deps + build wasm + render static page
#   make wasm     = build the TinyGo WASM binary (b.wasm)
#   make pages    = run `apt-repo render` to write generator/index.html
#   make serve    = run the dev server on http://localhost:8088
#   make update   = bump skywire dep to develop HEAD, rebuild wasm, re-render pages
#   make clean    = remove all generated artifacts
#
# Why TinyGo only:
#   The apt-repo used to ship a Go-WASM variant alongside the TinyGo
#   one. After the skywire refactor chain (#2834 → #2837) made
#   TinyGo compilation viable for the full install-page surface, the
#   Go variant was dropped — the TinyGo blob is ~4× smaller (1.9 MB
#   vs 6 MB) with no functional difference. b.wasm is now the
#   TinyGo output; the wasm_exec.js shipped is TinyGo's loader
#   runtime (NOT the standard Go one — the two are not
#   interchangeable).
#
# The page is fully self-contained — WASM blob is base64-inlined
# into a single HTML file. No external fetches.

TINYGOROOT := $(shell tinygo env TINYGOROOT)
PORT       ?= 8088

.PHONY: all wasm pages serve update tidy clean

all: wasm pages

# Stock TinyGo (through 0.41.x) ships a broken net/http for the js/wasm target:
# roundtrip_js.go calls t.roundTrip(req), a method TinyGo never defines, so any
# wasm build that transitively imports net/http fails ("t.roundTrip undefined").
# ./cmd/wasm pulls net/http in via skywire's dmsg-discovery types (it never makes
# a request). We build against a SYMLINK overlay of $(TINYGOROOT) — fast, copies
# no data — with patches/roundtrip_fix_js.go dropped into net/http to supply the
# missing method. The overlay ($(TINYGO_OVERLAY)) is regenerated each build from
# the live toolchain, so it self-heals across TinyGo upgrades; delete the patch
# once TinyGo fixes this upstream.
TINYGO_OVERLAY := .tinygoroot
wasm:
	@cp "$(TINYGOROOT)/targets/wasm_exec.js" wasm_exec.js
	@rm -rf "$(TINYGO_OVERLAY)"
	@cp -asRT "$(TINYGOROOT)" "$(TINYGO_OVERLAY)"
	@cp patches/roundtrip_fix_js.go "$(TINYGO_OVERLAY)/src/net/http/roundtrip_fix_js.go"
	TINYGOROOT="$(CURDIR)/$(TINYGO_OVERLAY)" tinygo build -target wasm -no-debug -o b.wasm ./cmd/wasm

pages: wasm
	@go build -o apt-repo .
	./apt-repo render

serve: wasm
	@go build -o apt-repo .
	./apt-repo serve -port $(PORT)

# Bump skywire dep to the latest RELEASE TAG (not develop HEAD),
# tidy, rebuild. The install page's autoconfig flag set is lifted
# live from the WASM-built version of pkg/skywireconfig/autoconfigcmd
# at runtime — so pinning to a release tag means the flags shown
# match what `apt install skywire-bin` / `yay -S skywire-bin` /
# the Windows MSI actually deliver to the operator. The Windows
# MSI URL on github.com/releases also embeds the version in the
# filename; using a release tag keeps that URL valid (develop
# pseudo-versions don't have matching MSI artifacts).
#
# For development against develop HEAD, override:
#   SKYWIRE_REF=develop make update
#
# `git ls-remote --tags --refs --sort='version:refname'` orders
# tags numerically (so v1.3.10 > v1.3.9, not lexicographic). We
# take the last entry. The `--refs` flag strips peeled tag refs
# (`^{}` suffixes) so we only see canonical refs/tags/<tag> lines.
update:
	@if [ -z "$$SKYWIRE_REF" ]; then \
	  REF=$$(git ls-remote --tags --refs --sort='version:refname' https://github.com/skycoin/skywire | tail -n1 | awk '{print $$2}' | sed 's|refs/tags/||'); \
	else \
	  REF="$$SKYWIRE_REF"; \
	fi; \
	echo "Pinning skywire to $$REF" && \
	go get github.com/skycoin/skywire@$$REF
	go mod tidy
	$(MAKE) all

tidy:
	go mod tidy

clean:
	rm -f apt-repo b.wasm wasm_exec.js
	rm -rf generator/
