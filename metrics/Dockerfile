FROM golang:1.16-alpine AS builder
ARG revision
WORKDIR /source
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags "-extldflags '-static' -X main.Revision=$revision -X main.BuildDate=$(date -Iseconds)" -o metrics .

FROM scratch
COPY --from=builder /source/metrics /
ENTRYPOINT ["/metrics"]
CMD ["-log-format", "json"]