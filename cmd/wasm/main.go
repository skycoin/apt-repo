// Package main is the browser-side WASM binary for the
// deb.skywire.dev / deb.theskywirenetwork.net install page.
//
// It exposes five JS-callable functions:
//
//	autoconfigFlags()         → JSON of the autoconfig flag set, lifted
//	                            live from pkg/skywireconfig/autoconfigcmd.
//	                            The HTML form renders one input per flag
//	                            from this metadata, so the form stays in
//	                            sync with the skywire binary version this
//	                            WASM was built against.
//	autoconfigHelp()          → cmd.UsageString() — the exact operator-
//	                            facing --help text. Shown in a
//	                            collapsible panel under the form.
//	generateKeypair()         → {pk, sk} hex strings from
//	                            pkg/skywireconfig/keypair, for the
//	                            "Generate a fresh visor identity" button.
//	publicKeyFromSecret(sk)   → derive pk for a paste-existing-SK flow.
//	generateVisorConfig(opts) → composed skywire.json from genvisor.
//	                            opts is a JS object {sk, ishv, hvpks,
//	                            reward_address, is_public, test_env}; all
//	                            optional. Returns indented JSON as a
//	                            string ready for blob download.
//
// All five are pure functions — no network calls, no DOM access.
// The HTML rendering layer (index.tmpl.html) is responsible for
// turning their outputs into the one-line install command + the
// downloadable /etc/skywire.conf file + the downloadable
// /opt/skywire/skywire.json.
//
// Build:
//
//	# Standard Go WASM (~4 MB):
//	GOOS=js GOARCH=wasm go build -ldflags="-s -w" -o b.wasm ./cmd/wasm
//
//	# TinyGo WASM (~700 KB):
//	tinygo build -target wasm -no-debug -o b-tiny.wasm ./cmd/wasm
//
// Both are embedded into index.html as base64 by the apt-repo's
// top-level main.go (the dev server + page generator).

//go:build js && wasm

package main

import (
	"encoding/json"
	"strings"
	"syscall/js"

	"github.com/spf13/pflag"

	skycipher "github.com/skycoin/skycoin/src/cipher"
	"github.com/skycoin/skycoin/src/cipher/bip32"
	"github.com/skycoin/skywire/pkg/buildinfo"
	"github.com/skycoin/skywire/pkg/cipher"
	"github.com/skycoin/skywire/pkg/skywireconfig/autoconfigcmd"
	"github.com/skycoin/skywire/pkg/skywireconfig/genvisor"
	"github.com/skycoin/skywire/pkg/skywireconfig/keypair"
)

// rewardXpubPreviewN is how many child addresses validateRewardAddress
// derives from an xpub so the operator can eyeball that derivation
// produces the addresses they expect.
const rewardXpubPreviewN = 5

// flagInfo is the JSON shape the HTML form consumes per flag.
// Field names use the same lowercase-underscore convention the rest
// of the skywire JSON surface uses so the JS side has zero
// translation to do.
type flagInfo struct {
	Name        string `json:"name"`
	Short       string `json:"short,omitempty"`
	Type        string `json:"type"` // "bool" | "string" | "int"
	DefaultVal  string `json:"default,omitempty"`
	Description string `json:"description"`

	// EnvKey is the SKYENV variable in /etc/skywire.conf this flag
	// writes when set. Empty for display-only flags (just --verbose).
	EnvKey string `json:"env_key,omitempty"`

	// EnvFormat is the wire encoding for the .conf line:
	// "bool", "string", "int", or "bashArray".
	EnvFormat string `json:"env_format,omitempty"`

	// EnvNegate is true for --no-X negation flags — the form
	// renderer collapses a positive+negation pair into one ternary
	// widget (ON / OFF / leave-alone) and uses this to know which
	// emits which.
	EnvNegate bool `json:"env_negate,omitempty"`

	// EnvDefault is the effective default config-gen uses when the
	// SKYENV variable is unset. Empty for flags whose default is
	// also empty (no useful hint to show). Surface populated only
	// for the curated subset where the value is non-trivial — see
	// autoconfigcmd's EnvMapping.Default for the source of truth.
	EnvDefault string `json:"env_default,omitempty"`
}

func main() {
	cmd := autoconfigcmd.New(&autoconfigcmd.Values{})
	envMap := autoconfigcmd.EnvMap()

	js.Global().Set("autoconfigFlags", js.FuncOf(func(this js.Value, args []js.Value) any {
		// Walk the cobra flag set in registration order so the
		// form renders in the same order operators see on the CLI.
		flags := make([]flagInfo, 0)
		cmd.Flags().VisitAll(func(f *pflag.Flag) {
			info := flagInfo{
				Name:        f.Name,
				Short:       f.Shorthand,
				Type:        f.Value.Type(),
				DefaultVal:  f.DefValue,
				Description: f.Usage,
			}
			if m, ok := envMap[f.Name]; ok {
				info.EnvKey = m.Key
				info.EnvFormat = string(m.Format)
				info.EnvNegate = m.Negate
				info.EnvDefault = m.Default
			}
			flags = append(flags, info)
		})
		buf, err := json.Marshal(flags)
		if err != nil {
			return js.ValueOf(`{"error":"` + err.Error() + `"}`)
		}
		return js.ValueOf(string(buf))
	}))

	js.Global().Set("autoconfigHelp", js.FuncOf(func(this js.Value, args []js.Value) any {
		return js.ValueOf(cmd.UsageString())
	}))

	js.Global().Set("skywireVersion", js.FuncOf(func(this js.Value, args []js.Value) any {
		// Version of the skywire dep this WASM was built against,
		// from Go's runtime/debug.ReadBuildInfo. Used by the JS
		// side for the Windows-MSI download URL (release asset
		// filenames include the version) so the install page
		// always points at the same release whose flag set the
		// operator is configuring.
		//
		// We strip the leading "v" and any pseudo-version suffix
		// (the "-0.20260526..." pattern Go appends when the dep
		// is pinned to a non-tag ref). The base version that
		// remains corresponds to the next release that the
		// pseudo-version is anticipating — so the MSI URL is
		// valid once that release ships, even if apt-repo is
		// currently pinned to develop HEAD ahead of the tag.
		v := buildinfo.DepVersion("github.com/skycoin/skywire")
		if len(v) > 0 && v[0] == 'v' {
			v = v[1:]
		}
		if i := strings.Index(v, "-"); i > 0 {
			v = v[:i]
		}
		return js.ValueOf(v)
	}))

	js.Global().Set("generateKeypair", js.FuncOf(func(this js.Value, args []js.Value) any {
		pk, sk := keypair.Generate()
		out := map[string]string{"pk": pk, "sk": sk}
		buf, _ := json.Marshal(out)
		return js.ValueOf(string(buf))
	}))

	js.Global().Set("publicKeyFromSecret", js.FuncOf(func(this js.Value, args []js.Value) any {
		if len(args) < 1 {
			return js.ValueOf(`{"error":"sk required"}`)
		}
		pk, err := keypair.FromSecretKey(args[0].String())
		if err != nil {
			return js.ValueOf(`{"error":"` + err.Error() + `"}`)
		}
		return js.ValueOf(`{"pk":"` + pk + `"}`)
	}))

	// validatePubKeys validates a comma-separated list of hex public
	// keys via the real cipher.PubKey parser (curve-point validation,
	// not a length heuristic). Returns {ok, count, invalid:[…]} — ok
	// is true when every non-empty entry parses (an empty list is ok:
	// the field is optional). Used to validate hvpks / any PK input
	// inline as the operator types.
	js.Global().Set("validatePubKeys", js.FuncOf(func(this js.Value, args []js.Value) any {
		if len(args) < 1 {
			return marshalJS(map[string]any{"ok": false, "count": 0, "invalid": []string{}})
		}
		invalid := make([]string, 0)
		count := 0
		for _, s := range strings.Split(args[0].String(), ",") {
			s = strings.TrimSpace(s)
			if s == "" {
				continue
			}
			count++
			var pk cipher.PubKey
			if err := pk.Set(s); err != nil {
				invalid = append(invalid, s)
			}
		}
		return marshalJS(map[string]any{"ok": len(invalid) == 0, "count": count, "invalid": invalid})
	}))

	// validateRewardAddress validates a reward address the way skywire
	// accepts it: either a base58 skycoin address OR a bip32 xpub
	// extended public key. Returns {type:"address"|"xpub"|"invalid",
	// error?, derived?}. For an xpub it derives the first
	// rewardXpubPreviewN child addresses so the operator can confirm
	// derivation matches their wallet. Validation is real (checksum /
	// curve), never length-based.
	js.Global().Set("validateRewardAddress", js.FuncOf(func(this js.Value, args []js.Value) any {
		if len(args) < 1 {
			return marshalJS(map[string]any{"type": "invalid", "error": "address required"})
		}
		s := strings.TrimSpace(args[0].String())
		if s == "" {
			return marshalJS(map[string]any{"type": "invalid", "error": "empty"})
		}
		// Plain skycoin address (base58 + checksum) first.
		if _, err := skycipher.DecodeBase58Address(s); err == nil {
			return marshalJS(map[string]any{"type": "address"})
		}
		// Otherwise try an xpub extended public key + derivation preview.
		xpub, err := bip32.DeserializeEncodedPublicKey(s)
		if err != nil {
			return marshalJS(map[string]any{"type": "invalid",
				"error": "not a valid skycoin address or xpub key"})
		}
		derived := make([]string, 0, rewardXpubPreviewN)
		for i := uint32(0); i < rewardXpubPreviewN; i++ {
			child, cerr := xpub.NewPublicChildKey(i)
			if cerr != nil {
				continue // skip the astronomically-rare impossible child
			}
			cpk, perr := skycipher.NewPubKey(child.Key)
			if perr != nil {
				continue
			}
			derived = append(derived, skycipher.AddressFromPubKey(cpk).String())
		}
		return marshalJS(map[string]any{"type": "xpub", "derived": derived})
	}))

	js.Global().Set("generateVisorConfig", js.FuncOf(func(this js.Value, args []js.Value) any {
		opts, err := buildVisorConfigOptions(args)
		if err != nil {
			return js.ValueOf(`{"error":"` + err.Error() + `"}`)
		}
		v, err := genvisor.Generate(opts)
		if err != nil {
			return js.ValueOf(`{"error":"` + err.Error() + `"}`)
		}
		return js.ValueOf(string(genvisor.MustMarshalJSON(v)))
	}))

	// Signal the JS side that all functions are wired. Without
	// this, the page's onLoad hook can fire before the WASM
	// finishes installing its globals.
	js.Global().Get("dispatchEvent").Invoke(
		js.Global().Get("Event").New("skywire-wasm-ready"),
	)

	// Block forever so the JS-side functions stay callable. The
	// Go runtime tears down `js.FuncOf` callbacks when main
	// returns, which would surface as "TypeError: ... is not a
	// function" on every later invocation.
	select {}
}

// buildVisorConfigOptions translates the single JS-object argument
// passed by the form into a genvisor.Options struct.
//
// The JS shape is `{sk?, ishv?, hvpks?, reward_address?,
// is_public?, test_env?}` — every field is optional. Strings get
// trimmed; bools come through as JS booleans. Empty / missing
// values fall back to genvisor's zero defaults.
//
// Errors come from key parsing — a bad SK or a malformed
// comma-separated PK in hvpks. Both are bubbled back to the
// caller as `{error: "..."}`.
func buildVisorConfigOptions(args []js.Value) (genvisor.Options, error) {
	var opts genvisor.Options
	if len(args) < 1 || args[0].IsUndefined() || args[0].IsNull() {
		return opts, nil
	}
	obj := args[0]

	if v := obj.Get("sk"); !v.IsUndefined() && !v.IsNull() && v.String() != "" {
		var sk cipher.SecKey
		if err := sk.Set(strings.TrimSpace(v.String())); err != nil {
			return opts, jsErr("sk: " + err.Error())
		}
		opts.SecretKey = sk
	}

	if v := obj.Get("ishv"); !v.IsUndefined() && !v.IsNull() {
		opts.IsHypervisor = v.Bool()
	}

	if v := obj.Get("hvpks"); !v.IsUndefined() && !v.IsNull() && v.String() != "" {
		raw := strings.Split(v.String(), ",")
		pks := make([]cipher.PubKey, 0, len(raw))
		for _, s := range raw {
			s = strings.TrimSpace(s)
			if s == "" {
				continue
			}
			var pk cipher.PubKey
			if err := pk.Set(s); err != nil {
				return opts, jsErr("hvpks: " + err.Error())
			}
			pks = append(pks, pk)
		}
		opts.HypervisorPKs = pks
	}

	if v := obj.Get("reward_address"); !v.IsUndefined() && !v.IsNull() {
		opts.RewardAddress = strings.TrimSpace(v.String())
	}

	if v := obj.Get("is_public"); !v.IsUndefined() && !v.IsNull() {
		opts.IsPublic = v.Bool()
	}

	if v := obj.Get("test_env"); !v.IsUndefined() && !v.IsNull() {
		opts.TestEnv = v.Bool()
	}

	return opts, nil
}

// marshalJS JSON-encodes v and returns it as a JS string value.
// On the (unexpected) marshal error it returns an {error:…} object
// so the JS side always receives parseable JSON.
func marshalJS(v any) any {
	buf, err := json.Marshal(v)
	if err != nil {
		return js.ValueOf(`{"error":"marshal: ` + err.Error() + `"}`)
	}
	return js.ValueOf(string(buf))
}

// jsErr wraps a plain message into a stdlib error. We keep the
// indirection so future enrichment (annotated context, structured
// error JSON shape, etc.) has a single edit point.
func jsErr(msg string) error {
	return &jsError{msg: msg}
}

type jsError struct{ msg string }

func (e *jsError) Error() string { return e.msg }
