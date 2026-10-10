FROM golang:1.27 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/wispie-server ./cmd/wispie-server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/wispie-server /wispie-server
ENV WISPIE_ADDR=:8080 WISPIE_DATA_DIR=/data
VOLUME /data
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/wispie-server"]
