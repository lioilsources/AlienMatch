package api

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

type okScorer struct{ frames int }

func (o *okScorer) Score(_ context.Context, in moodscore.Input) (mood.VLScore, error) {
	o.frames = len(in.Frames)
	return mood.VLScore{Energy: 0.9, Valence: 0.9, Confidence: 1}, nil
}

func mediaServer(t *testing.T, sc moodscore.Scorer) *httptest.Server {
	f := servicetest.New()
	f.Settings_["me"] = service.Settings{VLEnabled: true, Weights: mood.DefaultWeights()}
	svc := &service.Service{Store: f, Scorer: sc, Now: func() time.Time { return now }}
	srv := httptest.NewServer(Handler(svc, DevAuth{}, slog.New(slog.NewTextHandler(io.Discard, nil))))
	t.Cleanup(srv.Close)
	return srv
}

func multipartBody(parts map[string][][]byte) (*bytes.Buffer, string) {
	var b bytes.Buffer
	w := multipart.NewWriter(&b)
	for name, vals := range parts {
		for _, v := range vals {
			if name == "frame" || name == "audio" {
				fw, _ := w.CreateFormFile(name, name)
				_, _ = fw.Write(v)
			} else {
				_ = w.WriteField(name, string(v))
			}
		}
	}
	_ = w.Close()
	return &b, w.FormDataContentType()
}

func post(t *testing.T, srv *httptest.Server, body *bytes.Buffer, ct string) (int, string) {
	req, _ := http.NewRequest("POST", srv.URL+"/v1/checkins/media", body)
	req.Header.Set("Content-Type", ct)
	req.Header.Set("X-AlienMatch-User", "me")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

var jpg = []byte{0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3}

func TestMediaCheckinEndpoint(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("TMPDIR", tmp)
	sc := &okScorer{}
	srv := mediaServer(t, sc)
	big := bytes.Repeat([]byte{7}, 1900<<10) // near the audio limit
	body, ct := multipartBody(map[string][][]byte{"mode": {[]byte("video")}, "self": {[]byte("0.7")}, "lang": {[]byte("cs")}, "frame": {jpg, jpg, jpg}, "audio": {big}})
	code, resp := post(t, srv, body, ct)
	if code != 200 || !strings.Contains(resp, `"signal":true`) || sc.frames != 3 {
		t.Fatalf("%d %s frames=%d", code, resp, sc.frames)
	}
	if entries, _ := os.ReadDir(tmp); len(entries) != 0 {
		t.Fatalf("check-in media touched the disk: %v", entries)
	}
	cases := []map[string][][]byte{
		{"mode": {[]byte("video")}, "self": {[]byte("0.7")}},                                                 // no frames
		{"mode": {[]byte("video")}, "self": {[]byte("0.7")}, "frame": {[]byte("png?")}},                      // not jpeg
		{"mode": {[]byte("video")}, "self": {[]byte("0.7")}, "frame": {jpg, jpg, jpg, jpg}},                  // too many
		{"mode": {[]byte("voice")}, "self": {[]byte("0.7")}, "audio": {[]byte("a")}, "text": {[]byte("hi")}}, // unknown part
		{"mode": {[]byte("self")}, "self": {[]byte("0.7")}, "audio": {[]byte("a")}},                          // self has no media
		{"mode": {[]byte("voice")}, "self": {[]byte("1.7")}, "audio": {[]byte("a")}},                         // out of range
	}
	for i, c := range cases {
		b, ct := multipartBody(c)
		if code, resp := post(t, srv, b, ct); code != 400 {
			t.Errorf("case %d: %d %s", i, code, resp)
		}
	}
}

func TestConfigReportsScoring(t *testing.T) {
	for _, sc := range []moodscore.Scorer{nil, &okScorer{}} {
		srv := mediaServer(t, sc)
		res, _ := http.Get(srv.URL + "/v1/config")
		b, _ := io.ReadAll(res.Body)
		res.Body.Close()
		want := `"mood_scoring":` + map[bool]string{true: "true", false: "false"}[sc != nil]
		if !strings.Contains(string(b), want) {
			t.Errorf("config %s, want %s", b, want)
		}
	}
}
