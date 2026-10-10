// Package config loads server settings from the environment.
package config

import (
	"fmt"
	"net/netip"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Addr             string
	DataDir          string
	TrustedProxies   []netip.Prefix
	RegistrationOpen bool
	PowBits          int
	QuotaBytes       int64
	InactiveDays     int
	MaxDeltaBytes    int64
	ChunkBytes       int64

	GlobalPerMin      int
	GlobalBurst       int
	RegisterPerHour   int
	RegisterPerDay    int
	RegisterGlobalHr  int
	LoginPerMin       int
	RecoverIPPerHour  int
	RecoverUserPerDay int
	SyncPerMin        int
	DeltaPushPerMin   int
}

func Default() Config {
	return Config{
		Addr:              ":8080",
		DataDir:           "./data",
		RegistrationOpen:  true,
		PowBits:           22,
		QuotaBytes:        200 << 20,
		MaxDeltaBytes:     4 << 20,
		ChunkBytes:        1 << 20,
		GlobalPerMin:      120,
		GlobalBurst:       30,
		RegisterPerHour:   5,
		RegisterPerDay:    20,
		RegisterGlobalHr:  200,
		LoginPerMin:       20,
		RecoverIPPerHour:  5,
		RecoverUserPerDay: 5,
		SyncPerMin:        120,
		DeltaPushPerMin:   30,
	}
}

// FromEnv applies WISPIE_* overrides on top of defaults.
func FromEnv(get func(string) string) (Config, error) {
	c := Default()
	var err error
	str := func(k string, dst *string) {
		if v := get(k); v != "" {
			*dst = v
		}
	}
	num := func(k string, dst *int) {
		if v := get(k); v != "" && err == nil {
			n, e := strconv.Atoi(v)
			if e != nil || n < 0 {
				err = fmt.Errorf("%s: invalid number %q", k, v)
				return
			}
			*dst = n
		}
	}
	str("WISPIE_ADDR", &c.Addr)
	str("WISPIE_DATA_DIR", &c.DataDir)
	switch strings.ToLower(get("WISPIE_REGISTRATION")) {
	case "", "open":
	case "closed":
		c.RegistrationOpen = false
	default:
		return c, fmt.Errorf("WISPIE_REGISTRATION must be open or closed")
	}
	num("WISPIE_POW_BITS", &c.PowBits)
	num("WISPIE_INACTIVE_DAYS", &c.InactiveDays)
	num("WISPIE_RL_GLOBAL_PER_MIN", &c.GlobalPerMin)
	num("WISPIE_RL_GLOBAL_BURST", &c.GlobalBurst)
	num("WISPIE_RL_REGISTER_PER_HOUR", &c.RegisterPerHour)
	num("WISPIE_RL_REGISTER_PER_DAY", &c.RegisterPerDay)
	num("WISPIE_RL_REGISTER_GLOBAL_PER_HOUR", &c.RegisterGlobalHr)
	num("WISPIE_RL_LOGIN_PER_MIN", &c.LoginPerMin)
	num("WISPIE_RL_RECOVER_IP_PER_HOUR", &c.RecoverIPPerHour)
	num("WISPIE_RL_RECOVER_USER_PER_DAY", &c.RecoverUserPerDay)
	num("WISPIE_RL_SYNC_PER_MIN", &c.SyncPerMin)
	num("WISPIE_RL_DELTA_PUSH_PER_MIN", &c.DeltaPushPerMin)
	if v := get("WISPIE_QUOTA_MB"); v != "" && err == nil {
		n, e := strconv.Atoi(v)
		if e != nil || n <= 0 {
			err = fmt.Errorf("WISPIE_QUOTA_MB: invalid %q", v)
		} else {
			c.QuotaBytes = int64(n) << 20
		}
	}
	if err != nil {
		return c, err
	}
	if c.PowBits > 40 {
		return c, fmt.Errorf("WISPIE_POW_BITS too large")
	}
	for _, p := range strings.Split(get("WISPIE_TRUSTED_PROXIES"), ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if pf, e := netip.ParsePrefix(p); e == nil {
			c.TrustedProxies = append(c.TrustedProxies, pf)
		} else if a, e := netip.ParseAddr(p); e == nil {
			c.TrustedProxies = append(c.TrustedProxies, netip.PrefixFrom(a, a.BitLen()))
		} else {
			return c, fmt.Errorf("WISPIE_TRUSTED_PROXIES: invalid entry %q", p)
		}
	}
	return c, nil
}

func FromOS() (Config, error) { return FromEnv(os.Getenv) }
