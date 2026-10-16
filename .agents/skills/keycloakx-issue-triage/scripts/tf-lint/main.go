// tf-lint — reproduces the pre-flight lint of terraform-provider-helm
// (helm_release with `lint = true`) outside of Terraform.
//
// The provider calls Helm's lint library directly and wraps errors as
// "malformed chart or values: ..." — an error users see from Terraform but
// never from the Helm CLI. This program mirrors lintChart()/resultToError()
// of hashicorp/terraform-provider-helm (helm/resource_helm_release.go).
//
// Built by repro.sh against the Helm library version the user's provider
// version bundles (see `repro.sh tf-lint --help`). Do not run directly.
//
// Usage: tf-lint CHART_DIR [-f values.yaml]... [--set k=v]... [--set-string k=v]...
//
// Values are merged like the provider does: `values` files in order, then
// `set` (typed) and `set_string` entries on top.
package main

import (
	"fmt"
	"os"
	"strings"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chartutil"
	"helm.sh/helm/v3/pkg/strvals"
)

func mergeMaps(a, b map[string]interface{}) map[string]interface{} {
	out := make(map[string]interface{}, len(a))
	for k, v := range a {
		out[k] = v
	}
	for k, v := range b {
		if bv, ok := v.(map[string]interface{}); ok {
			if av, ok := out[k].(map[string]interface{}); ok {
				out[k] = mergeMaps(av, bv)
				continue
			}
		}
		out[k] = v
	}
	return out
}

func die(format string, a ...interface{}) {
	fmt.Fprintf(os.Stderr, "tf-lint: "+format+"\n", a...)
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		die("usage: tf-lint CHART_DIR [-f FILE]... [--set K=V]... [--set-string K=V]...")
	}
	chart := os.Args[1]
	values := map[string]interface{}{}
	args := os.Args[2:]
	for i := 0; i < len(args); i++ {
		if i+1 >= len(args) {
			die("missing argument for %s", args[i])
		}
		switch args[i] {
		case "-f":
			v, err := chartutil.ReadValuesFile(args[i+1])
			if err != nil {
				die("reading %s: %v", args[i+1], err)
			}
			values = mergeMaps(values, v.AsMap())
		case "--set":
			if err := strvals.ParseInto(args[i+1], values); err != nil {
				die("--set %s: %v", args[i+1], err)
			}
		case "--set-string":
			if err := strvals.ParseIntoString(args[i+1], values); err != nil {
				die("--set-string %s: %v", args[i+1], err)
			}
		default:
			die("unknown argument %s", args[i])
		}
		i++
	}

	// --- verbatim logic of terraform-provider-helm lintChart() ---
	l := action.NewLint()
	result := l.Run([]string{chart}, values)

	sev := map[int]string{0: "UNKNOWN", 1: "INFO", 2: "WARNING", 3: "ERROR"}
	fmt.Println("lint messages (all severities; only ERROR fails the provider):")
	if len(result.Messages) == 0 {
		fmt.Println("  (none)")
	}
	for _, m := range result.Messages {
		fmt.Printf("  [%s] %s: %v\n", sev[m.Severity], m.Path, m.Err)
	}

	// --- verbatim logic of terraform-provider-helm resultToError() ---
	if len(result.Errors) == 0 {
		fmt.Println("TF-LINT: OK — terraform-provider-helm lint would pass")
		return
	}
	messages := []string{}
	for _, msg := range result.Messages {
		for _, err := range result.Errors {
			if err == msg.Err {
				messages = append(messages, fmt.Sprintf("%s: %s", msg.Path, msg.Err))
				break
			}
		}
	}
	fmt.Printf("TF-LINT: FAILED — terraform would report:\nmalformed chart or values: \n\t%s\n", strings.Join(messages, "\n\t"))
	os.Exit(1)
}
