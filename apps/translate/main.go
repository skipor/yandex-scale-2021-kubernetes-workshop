package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	"github.com/yandex-cloud/go-genproto/yandex/cloud/ai/translate/v2"
	"github.com/yandex-cloud/go-sdk"
	translatesdk "github.com/yandex-cloud/go-sdk/gen/ai/translate"
	"github.com/yandex-cloud/go-sdk/iamkey"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// translate app serves http on 80 port, accepts POST requests and translates its body to
// language selected by 'to' query param ('en' by default).

func main() {
	var serviceAccountKeyPath string
	flag.StringVar(&serviceAccountKeyPath, "service-account-key", "", "Yandex Cloud Service Account Key")
	flag.Parse()
	if serviceAccountKeyPath == "" {
		log.Fatalf("--service-account-key flag required")
	}

	translation, err := newTranslateClient(serviceAccountKeyPath)
	if err != nil {
		log.Fatalf("%+v", err)
	}
	http.Handle("/", &handler{
		client: translation,
	})

	log.Println("Serving translate on port :80")
	err = http.ListenAndServe(":80", nil)
	if err != nil {
		log.Fatalf("Listen ans serve: %+v", err)
	}
}

type handler struct {
	client *translatesdk.TranslationServiceClient
}

func (h handler) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	resp := h.translate(req)
	rw.WriteHeader(resp.code)
	_, err := rw.Write(resp.body)
	if err != nil {
		log.Printf("Response write failed: %+v", err)
	}
}

func (h handler) translate(req *http.Request) *handlerResp {
	tr, resp := h.readReq(req)
	if resp != nil {
		return resp
	}
	trResp, err := h.client.Translate(req.Context(), tr)
	if err != nil {
		log.Printf("Translate failed: %+v", err)
		return &handlerResp{code: h.errCode(err), body: []byte(err.Error())}
	}
	out := &bytes.Buffer{}
	for i, tr := range trResp.Translations {
		if i != 0 {
			out.WriteByte('\n')
		}
		out.WriteString(tr.Text)
	}
	log.Printf("Output text: %s", out.Bytes())
	return &handlerResp{
		code: http.StatusOK,
		body: out.Bytes(),
	}
}

func (h handler) readReq(req *http.Request) (*translate.TranslateRequest, *handlerResp) {
	in, err := ioutil.ReadAll(req.Body)
	if err != nil {
		log.Printf("Request read err: %+v", err)
		return nil, &handlerResp{code: http.StatusServiceUnavailable}
	}
	log.Printf("Input text: %s", in)
	query := req.URL.Query()
	from := query.Get("from")
	to := query.Get("to")
	if to == "" {
		to = "en"
	}
	return &translate.TranslateRequest{
		SourceLanguageCode: from,
		TargetLanguageCode: to,
		Texts:              []string{string(in)},
	}, nil
}

type handlerResp struct {
	code int
	body []byte
}

func (h handler) errCode(err error) int {
	code := http.StatusInternalServerError
	switch status.Code(err) {
	case codes.InvalidArgument:
		code = http.StatusBadRequest
	case codes.Unauthenticated, codes.PermissionDenied:
		code = http.StatusUnauthorized
	}
	return code
}

func newTranslateClient(serviceAccountKeyPath string) (*translatesdk.TranslationServiceClient, error) {
	key, err := iamkey.ReadFromJSONFile(serviceAccountKeyPath)
	if err != nil {
		return nil, fmt.Errorf("service account key file '%s' read: %+v", serviceAccountKeyPath, err)
	}
	creds, err := ycsdk.ServiceAccountKey(key)
	if err != nil {
		return nil, fmt.Errorf("service account creds: %+v", err)
	}
	sdk, err := ycsdk.Build(context.Background(), ycsdk.Config{
		Credentials: creds,
	})
	return sdk.AI().Translate().Translation(), nil
}
