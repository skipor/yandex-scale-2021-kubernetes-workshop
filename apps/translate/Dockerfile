FROM golang:1.17.2 as builder
WORKDIR $GOPATH/src/app

# When app changes, 'go mod download' will be cached.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /go/bin/translate .

FROM scratch
COPY --from=builder /go/bin/translate /translate
ENTRYPOINT ["/translate"]



