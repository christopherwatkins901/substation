package sink

import (
	"context"
	"fmt"
	"os"

	"github.com/brexhq/substation/internal/http"
	"github.com/brexhq/substation/internal/json"
)

/*
HTTP implements the Sink interface and POSTs data to an HTTP(S) endpoint. More information is available in the README.

URL: HTTP(S) endpoint that data is sent to
Headers: maps keys from JSON data to an HTTP header
*/
type HTTP struct {
	client  http.HTTP
	URL     string `mapstructure:"url"`
	Headers []struct {
		Key    string `mapstructure:"key"`
		Header string `mapstructure:"header"`
	} `mapstructure:"headers"`
}

// Send sends a channel of bytes to the HTTP destination defined by this sink.
func (sink *HTTP) Send(ctx context.Context, ch chan []byte, kill chan struct{}) error {
	if !sink.client.IsEnabled() {
		sink.client.Setup()
		if _, ok := os.LookupEnv("AWS_XRAY_DAEMON_ADDRESS"); ok {
			sink.client.EnableXRay()
		}
	}

	for data := range ch {
		select {
		case <-kill:
			return nil
		default:
			var headers []http.Header

			if json.Valid(data) {
				headers = append(headers, http.Header{
					Key:   "Content-Type",
					Value: "application/json",
				})

				for _, h := range sink.Headers {
					v := json.Get(data, h.Header).String()
					headers = append(headers, http.Header{
						Key:   h.Key,
						Value: v,
					})
				}
			}

			_, err := sink.client.Post(ctx, sink.URL, string(data), headers...)
			if err != nil {
				return fmt.Errorf("err failed to POST to URL %s: %v", sink.URL, err)
			}
		}
	}

	return nil
}