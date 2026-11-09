package api

import (
	"encoding/json"
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

func accountServer(t *testing.T) (*httptest.Server, *servicetest.Accounts, servicetest.Media) {
	t.Helper()
	acc, med := servicetest.NewAccounts(), servicetest.Media{}
	svc := &service.Service{Store: servicetest.New(), Accounts: acc, Media: med, Now: func() time.Time { return now }}
	srv := httptest.NewServer(Handler(svc, BearerAuth{Lookup: acc.UserByTokenHash}, slog.New(slog.NewTextHandler(io.Discard, nil))))
	t.Cleanup(srv.Close)
	return srv, acc, med
}

func call(t *testing.T, srv *httptest.Server, method, path, token, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

var jpeg = string([]byte{0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 'J', 'F', 'I', 'F'})

func TestAccountLifecycle(t *testing.T) {
	srv, acc, med := accountServer(t)
	if code, _ := call(t, srv, "POST", "/v1/accounts", "", `{"adult_confirmed":false}`); code != 400 {
		t.Fatalf("no 18+: %d", code)
	}
	if code, _ := call(t, srv, "POST", "/v1/accounts", "", `{"adult_confirmed":true,"email":"x@y.z"}`); code != 400 {
		t.Fatalf("e-mail must be rejected: %d", code)
	}
	code, body := call(t, srv, "POST", "/v1/accounts", "", `{"adult_confirmed":true,"mood_consent":false}`)
	if code != 201 {
		t.Fatalf("%d %s", code, body)
	}
	var cr CreateAccountResponse
	_ = json.Unmarshal([]byte(body), &cr)
	tok := cr.Token

	if code, _ := call(t, srv, "GET", "/v1/me", "wrong-token-wrong-token-wrong-token", ""); code != 401 {
		t.Fatalf("bad token: %d", code)
	}
	if code, _ := call(t, srv, "PUT", "/v1/me/photo", tok, jpeg); code != 409 {
		t.Fatalf("photo before profile: %d", code)
	}
	prof := `{"generation":"genz","status":"single","region":"CZ-PHA","intents":["coffee","tea"],"nickname":"Zq-7"}`
	if code, b := call(t, srv, "PUT", "/v1/me/profile", tok, prof); code != 204 {
		t.Fatalf("profile: %d %s", code, b)
	}
	if code, _ := call(t, srv, "PUT", "/v1/me/photo", tok, "not an image"); code != 400 {
		t.Fatalf("bad photo: %d", code)
	}
	for range 2 {
		if code, b := call(t, srv, "PUT", "/v1/me/photo", tok, jpeg); code != 204 {
			t.Fatalf("photo: %d %s", code, b)
		}
	}
	if len(med) != 1 {
		t.Fatalf("old photo not deleted: %v", med)
	}
	code, body = call(t, srv, "GET", "/v1/me", tok, "")
	if code != 200 || !strings.Contains(body, `"has_photo":true`) || !strings.Contains(body, `"mood_consent":false`) {
		t.Fatalf("me: %d %s", code, body)
	}
	if code, b := call(t, srv, "GET", "/v1/users/"+cr.UserID+"/photo", tok, ""); code != 200 || b != jpeg {
		t.Fatalf("photo get: %d", code)
	}
	if code, _ := call(t, srv, "DELETE", "/v1/me", tok, ""); code != 204 {
		t.Fatalf("delete: %d", code)
	}
	if len(med) != 0 || len(acc.Users) != 0 {
		t.Fatalf("leftovers after delete: media=%d users=%d", len(med), len(acc.Users))
	}
	if code, _ := call(t, srv, "GET", "/v1/me", tok, ""); code != 401 {
		t.Fatalf("token survives deletion: %d", code)
	}
}
