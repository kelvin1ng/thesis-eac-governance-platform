// CHAPTER3_REFERENCE.md §3.0: Virtual firewall CNF; port 8080, configurable rules.
// Layer 3: gosec static analysis applies (Table 1 Compliance Verification).
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/thesis-eac-governance-platform/apps/firewall/pkg/rule"
)

const defaultPort = "8080"

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	// Configurable rules: default allow 8080 (health), deny others for demo
	rules := []rule.Rule{
		{Action: "allow", Port: 8080},
		{Action: "deny", Port: 0},
	}
	if r := os.Getenv("FIREWALL_RULES"); r != "" {
		if err := json.Unmarshal([]byte(r), &rules); err != nil {
			log.Printf("WARN: invalid FIREWALL_RULES, using default: %v", err)
		}
	}
	engine := rule.NewEngine(rules)

	http.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	http.HandleFunc("/ready", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	http.HandleFunc("/rules", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{"rules": rules})
	})
	// Simulate packet check: GET /check?port=8080 -> allow/deny (netfilter stub)
	http.HandleFunc("/check", func(w http.ResponseWriter, r *http.Request) {
		portStr := r.URL.Query().Get("port")
		p, _ := strconv.Atoi(portStr)
		allowed := engine.AllowPort(uint16(p))
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]bool{"allowed": allowed})
	})

	log.Printf("firewall listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
