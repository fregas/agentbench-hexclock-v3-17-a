package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestTimeIsUTCAndFresh(t *testing.T) {
	instant := time.Date(2026, 10, 3, 18, 30, 45, 123456789, time.FixedZone("UTC+2", 2*60*60))
	h := handler(func() time.Time { return instant })
	for _, want := range []string{"2026-10-03T16:30:45.123456789Z", "2026-10-03T16:30:46.123456789Z"} {
		res := httptest.NewRecorder()
		h.ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/", nil))
		if res.Code != http.StatusOK {
			t.Fatalf("status = %d", res.Code)
		}
		if got := res.Header().Get("Content-Type"); got != "application/json" {
			t.Errorf("Content-Type = %q", got)
		}
		if got := res.Header().Get("Cache-Control"); got != "no-store" {
			t.Errorf("Cache-Control = %q", got)
		}
		var body map[string]string
		if err := json.Unmarshal(res.Body.Bytes(), &body); err != nil {
			t.Fatal(err)
		}
		if len(body) != 1 || body["time"] != want {
			t.Errorf("body = %v; want time %s", body, want)
		}
		instant = instant.Add(time.Second)
	}
}

func TestHealth(t *testing.T) {
	h := handler(func() time.Time { t.Fatal("health should not read clock"); return time.Time{} })
	res := httptest.NewRecorder()
	h.ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if res.Code != http.StatusOK || res.Body.String() != "{\"status\":\"ok\"}\n" {
		t.Fatalf("health response: %d %s", res.Code, res.Body)
	}
}

func TestInvalidRequests(t *testing.T) {
	for _, tc := range []struct {
		method string
		path   string
		status int
	}{
		{http.MethodGet, "/missing", http.StatusNotFound},
		{http.MethodGet, "/healthz/", http.StatusNotFound},
		{http.MethodPost, "/", http.StatusMethodNotAllowed},
		{http.MethodHead, "/", http.StatusMethodNotAllowed},
		{http.MethodDelete, "/healthz", http.StatusMethodNotAllowed},
	} {
		t.Run(tc.method+tc.path, func(t *testing.T) {
			res := httptest.NewRecorder()
			handler(time.Now).ServeHTTP(res, httptest.NewRequest(tc.method, tc.path, nil))
			if res.Code != tc.status || !json.Valid(res.Body.Bytes()) {
				t.Fatalf("response: %d %s", res.Code, res.Body)
			}
			if tc.status == http.StatusMethodNotAllowed && res.Header().Get("Allow") != "GET" {
				t.Error("missing Allow: GET")
			}
		})
	}
}
