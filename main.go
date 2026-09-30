// Package main is the apt-repo dev server and static-page generator
// for deb.skywire.dev / deb.theskywirenetwork.net.
//
// It hosts the WASM-backed install command generator (cmd/wasm)
// inline via a single HTML template. Two modes:
//
//	./apt-repo serve   # interactive dev — http://localhost:8088
//	./apt-repo render  # writes generator/index.html (snapshot for github pages)
//
// The HTML is a Go html/template populated with:
//   - The TinyGo wasm_exec.js runtime
//   - The base64-encoded TinyGo WASM blob built by the Makefile
//
// Both are embedded at apt-repo build time via go:embed, so the
// generated index.html is fully self-contained — no fetches, no
// CDN dependency, works offline once loaded.
//
// History: the apt-repo used to ship a Go-WASM variant alongside
// the TinyGo one. After the skywire refactor chain (#2834 →
// #2837) made TinyGo compilation viable for the full install-page
// surface, the Go variant was dropped — the TinyGo blob is ~4×
// smaller (1.9 MB vs 6 MB) with no functional difference.
package main

import (
	_ "embed"
	"encoding/base64"
	"flag"
	"fmt"
	htmpl "html/template"
	"log"
	"net/http"
	"os"
)

var (
	//go:embed b.wasm
	wasmData []byte
	//go:embed wasm_exec.js
	wasmExecJS []byte
	//go:embed index.tmpl.html
	indexTmpl string
)

type tmplData struct {
	WasmExecJs htmpl.JS
	WasmBase64 string
}

func renderPage() ([]byte, error) {
	t, err := htmpl.New("index").Parse(indexTmpl)
	if err != nil {
		return nil, err
	}
	data := tmplData{
		WasmExecJs: htmpl.JS(wasmExecJS), //nolint:gosec // embedded runtime JS; not user input
		WasmBase64: base64.StdEncoding.EncodeToString(wasmData),
	}
	var buf bytePtrSink
	if err := t.Execute(&buf, data); err != nil {
		return nil, err
	}
	return buf.b, nil
}

// bytePtrSink is a minimal io.Writer that accumulates into a slice.
// We use it instead of bytes.Buffer to keep the apt-repo binary
// import set small (no bytes pkg pull for one Write call).
type bytePtrSink struct{ b []byte }

func (s *bytePtrSink) Write(p []byte) (int, error) {
	s.b = append(s.b, p...)
	return len(p), nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: apt-repo {serve|render}")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "serve":
		cmdServe(os.Args[2:])
	case "render":
		cmdRender(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown mode %q (want serve | render)\n", os.Args[1])
		os.Exit(2)
	}
}

func cmdServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	port := fs.Int("port", 8088, "port to bind")
	if err := fs.Parse(args); err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()

	// "/generator/" — the install-command generator. The mirror's
	// "/" path is intentionally NOT handled here so the deploy
	// serves whatever falls back (e.g. GitHub Pages auto-renders
	// README.md). The generator lives at /generator/ and is linked
	// from the README.
	mux.HandleFunc("/generator/index.html", func(w http.ResponseWriter, r *http.Request) {
		serveInline(w)
	})
	mux.HandleFunc("/generator/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/generator/" && r.URL.Path != "/generator/index.html" {
			http.NotFound(w, r)
			return
		}
		serveInline(w)
	})

	log.Printf("apt-repo install-command generator on http://localhost:%d/generator/", *port)
	addr := fmt.Sprintf(":%d", *port)
	if err := http.ListenAndServe(addr, mux); err != nil { //nolint:gosec // dev-only server, no timeouts needed
		log.Fatal(err)
	}
}

func serveInline(w http.ResponseWriter) {
	page, err := renderPage()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(page)
}

func cmdRender(args []string) {
	fs := flag.NewFlagSet("render", flag.ExitOnError)
	outPath := fs.String("out", "generator/index.html", "output path for the rendered page")
	if err := fs.Parse(args); err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(parentDir(*outPath), 0o755); err != nil {
		log.Fatalf("mkdir %s: %v", parentDir(*outPath), err)
	}
	page, err := renderPage()
	if err != nil {
		log.Fatalf("render %s: %v", *outPath, err)
	}
	if err := os.WriteFile(*outPath, page, 0o644); err != nil { //nolint:gosec // page is HTML for github pages serving
		log.Fatalf("write %s: %v", *outPath, err)
	}
	log.Printf("wrote %s (TinyGo WASM, base64-inline)", *outPath)
}

func parentDir(p string) string {
	for i := len(p) - 1; i >= 0; i-- {
		if p[i] == '/' {
			return p[:i]
		}
	}
	return "."
}
