package api

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

func adminServer(t *testing.T, token string) (*httptest.Server, *servicetest.Admin) {
	adm := &servicetest.Admin{Reports: []service.ReportView{{ID: 1, CreatedAt: now, Sticker: &service.ReportedSticker{ID: 9, Kind: "preset", Preset: "fire", Moderation: "review"}}}}
	svc := &service.Service{Store: servicetest.New(), Admin: adm, Now: func() time.Time { return now }}
	srv := httptest.NewServer(Handler(svc, DevAuth{}, slog.New(slog.NewTextHandler(io.Discard, nil)), WithAdmin(token)))
	t.Cleanup(srv.Close)
	return srv, adm
}

func adminCall(t *testing.T, srv *httptest.Server, method, path, token, body string) (int, string) {
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("X-AlienMatch-User", "someone") // a normal user must not pass
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

func TestAdminQueue(t *testing.T) {
	srv, adm := adminServer(t, "s3cret-admin-token")
	if code, _ := adminCall(t, srv, "GET", "/v1/admin/reports", "", ""); code != 401 {
		t.Fatalf("no token: %d", code)
	}
	if code, _ := adminCall(t, srv, "GET", "/v1/admin/reports", "wrong", ""); code != 401 {
		t.Fatalf("wrong token: %d", code)
	}
	code, body := adminCall(t, srv, "GET", "/v1/admin/reports", "s3cret-admin-token", "")
	if code != 200 || !strings.Contains(body, `"preset":"fire"`) {
		t.Fatalf("%d %s", code, body)
	}
	if code, _ := adminCall(t, srv, "POST", "/v1/admin/reports/1/resolve", "s3cret-admin-token", `{"action":"ban"}`); code != 400 {
		t.Fatalf("bad action: %d", code)
	}
	if code, _ := adminCall(t, srv, "POST", "/v1/admin/reports/1/resolve", "s3cret-admin-token", `{"action":"remove"}`); code != 204 {
		t.Fatalf("resolve: %d", code)
	}
	if adm.Resolved[1] != "remove" {
		t.Fatalf("resolved=%v", adm.Resolved)
	}
	_, body = adminCall(t, srv, "GET", "/v1/admin/reports", "s3cret-admin-token", "")
	if strings.Contains(body, `"id":1`) {
		t.Fatalf("resolved report still open: %s", body)
	}
	code, body = adminCall(t, srv, "GET", "/admin", "", "")
	if code != 200 || !strings.Contains(body, "Fronta nahlášení") {
		t.Fatalf("admin page: %d", code)
	}
}

func TestAdminDisabledWithoutToken(t *testing.T) {
	srv, _ := adminServer(t, "")
	for _, p := range []string{"/admin", "/v1/admin/reports"} {
		if code, _ := adminCall(t, srv, "GET", p, "", ""); code != 404 {
			t.Errorf("%s: %d, want 404 when disabled", p, code)
		}
	}
}
