FROM golang:1.17.2 as builder
WORKDIR $GOPATH/src/app
COPY . .
RUN CGO_ENABLED=0 go build -o /go/bin/clock .

FROM scratch
COPY --from=builder /go/bin/clock /clock
ENTRYPOINT ["/clock"]



