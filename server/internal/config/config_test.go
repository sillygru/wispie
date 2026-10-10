package config

import "testing"

func TestFromEnv(t *testing.T) {
	env := map[string]string{
		"WISPIE_REGISTRATION": "closed", "WISPIE_QUOTA_MB": "50", "WISPIE_POW_BITS": "10",
		"WISPIE_TRUSTED_PROXIES": "10.0.0.0/8, 127.0.0.1",
	}
	c, err := FromEnv(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	if c.RegistrationOpen || c.QuotaBytes != 50<<20 || c.PowBits != 10 || len(c.TrustedProxies) != 2 {
		t.Fatalf("%+v", c)
	}
	if _, err := FromEnv(func(k string) string {
		return map[string]string{"WISPIE_REGISTRATION": "maybe"}[k]
	}); err == nil {
		t.Fatal("want error")
	}
}
