// CHAPTER3_REFERENCE.md §3.2.2, §3.2.3: Packet inspection rules; netfilter stub for gosec (Layer 3).
// Rule engine evaluates allow/deny by port; stub for netfilter hook (no CGo; gosec analyzes this package).
package rule

import (
	"net"
	"sync"
)

// Rule represents a firewall rule (allow/deny by port). Simulates packet inspection.
type Rule struct {
	Action string // "allow" or "deny"
	Port   uint16
}

// Engine evaluates rules against connection metadata. Netfilter stub: in production
// this would integrate with netfilter hooks; here we simulate for Layer 3 gosec analysis.
type Engine struct {
	mu    sync.RWMutex
	rules []Rule
}

// NewEngine returns a rule engine with the given rules.
func NewEngine(rules []Rule) *Engine {
	if rules == nil {
		rules = []Rule{}
	}
	return &Engine{rules: rules}
}

// AllowPort returns true if the given port is allowed by the rules (first match wins).
func (e *Engine) AllowPort(port uint16) bool {
	e.mu.RLock()
	defer e.mu.RUnlock()
	for _, r := range e.rules {
		if r.Port == port || r.Port == 0 {
			return r.Action == "allow"
		}
	}
	return false
}

// Eval simulates packet inspection: returns true if the "packet" (addr, port) is allowed.
// Netfilter stub: real implementation would use netfilter hooks for kernel-level filtering.
func (e *Engine) Eval(addr net.IP, port uint16) bool {
	_ = addr // stub: would be used for IP-based rules
	return e.AllowPort(port)
}

// SetRules updates rules (configurable at runtime per §3.0).
func (e *Engine) SetRules(rules []Rule) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.rules = rules
}
