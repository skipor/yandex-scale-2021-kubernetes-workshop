package main

import (
	"io"
	"log"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(rw http.ResponseWriter, req *http.Request) {
		log.Println("Got request")
		ts := time.Now().UTC().Format("2006-01-02T15:04:05.999Z07:00")
		rw.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(rw, ts)
	})
	log.Println("Serving clock on port :80")
	err := http.ListenAndServe(":80", nil)
	if err != nil {
		panic(err)
	}
}
