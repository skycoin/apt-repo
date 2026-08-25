// This file is overlaid into $TINYGOROOT/src/net/http at wasm-build time by the
// Makefile's `wasm` target — it is NOT part of this module.
//
// Why: stock TinyGo (through 0.41.x) ships a broken net/http for the js/wasm
// target. roundtrip_js.go's RoundTrip falls back to `t.roundTrip(req)` when the
// JS Fetch API is unavailable, but TinyGo never defines that lowercase method,
// so any wasm build that transitively imports net/http fails to compile with:
//
//	net/http/roundtrip_js.go: t.roundTrip undefined (has RoundTrip)
//
// Our install-command generator (./cmd/wasm) pulls net/http in transitively via
// skywire's dmsg-discovery types (genvisor → visorconfig → dmsg/disc), even
// though it never makes an HTTP request. Supplying the missing method unblocks
// the build. A wasm runtime without Fetch has no HTTP transport anyway, so the
// fallback simply errors. Remove this once TinyGo defines the method upstream.
//
// The _js.go suffix scopes it to GOOS=js by filename convention; the overlay
// scopes it to TinyGo builds.

package http

import "errors"

func (t *Transport) roundTrip(req *Request) (*Response, error) {
	return nil, errors.New("net/http: no transport (JS Fetch unavailable in this wasm runtime)")
}
